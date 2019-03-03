From RecoveryRefinement.Goose Require Import base.

(* Package simpledb implements a one-table version of LevelDB

   It buffers all writes in memory; to make data durable, call Compact().
   This operation re-writes all of the data in the database
   (including in-memory writes) in a crash-safe manner.
   Keys in the table are cached for efficient reads. *)

Module Table.
  (* A Table provides access to an immutable copy of data on the filesystem,
     along with an index for fast random access. *)
  Record t := mk {
    Index: Map uint64;
    File: File;
  }.
  Global Instance t_zero : HasGoZero t := mk (zeroValue _) (zeroValue _).
End Table.

(* CreateTable creates a new, empty table. *)
Definition CreateTable (p:string) : proc Table.t :=
  index <- Data.newMap uint64;
  f <- FS.create p;
  _ <- FS.close f;
  f2 <- FS.open p;
  Ret {| Table.Index := index;
         Table.File := f2; |}.

Module Entry.
  (* Entry represents a (key, value) pair. *)
  Record t := mk {
    Key: uint64;
    Value: slice.t byte;
  }.
  Global Instance t_zero : HasGoZero t := mk (zeroValue _) (zeroValue _).
End Entry.

(* DecodeUInt64 is a Decoder(uint64)

   All decoders have the shape func(p []byte) (T, uint64)

   The uint64 represents the number of bytes consumed; if 0,
   then decoding failed, and the value of type T should be ignored. *)
Definition DecodeUInt64 (p:slice.t byte) : proc (uint64 * uint64) :=
  if compare_to (slice.length p) 8 Lt
  then Ret (0, 0)
  else
    n <- Data.uint64Get p;
    Ret (n, 8).

(* DecodeEntry is a Decoder(Entry) *)
Definition DecodeEntry (data:slice.t byte) : proc (Entry.t * uint64) :=
  let! (key, l1) <- DecodeUInt64 data;
  if l1 == 0
  then
    Ret ({| Entry.Key := 0;
            Entry.Value := slice.nil _; |}, 0)
  else
    let! (valueLen, l2) <- DecodeUInt64 (slice.skip l1 data);
    if l2 == 0
    then
      Ret ({| Entry.Key := 0;
              Entry.Value := slice.nil _; |}, 0)
    else
      if compare_to (slice.length data) (l1 + l2 + valueLen) Lt
      then
        Ret ({| Entry.Key := 0;
                Entry.Value := slice.nil _; |}, 0)
      else
        let value := slice.subslice (l1 + l2) (l1 + l2 + valueLen) data in
        Ret ({| Entry.Key := key;
                Entry.Value := value; |}, l1 + l2 + valueLen).

Module lazyFileBuf.
  Record t := mk {
    offset: uint64;
    next: slice.t byte;
  }.
  Global Instance t_zero : HasGoZero t := mk (zeroValue _) (zeroValue _).
End lazyFileBuf.

(* readTableIndex parses a complete table on disk into a key->offset index *)
Definition readTableIndex (f:File) (index:Map uint64) : proc unit :=
  Loop (fun buf =>
        let! (e, l) <- DecodeEntry buf.(lazyFileBuf.next);
        if compare_to l 0 Gt
        then
          _ <- Data.mapAlter index e.(Entry.Key) (fun _ => Some (8 + buf.(lazyFileBuf.offset)));
          Continue {| lazyFileBuf.offset := buf.(lazyFileBuf.offset) + l;
                      lazyFileBuf.next := slice.skip l buf.(lazyFileBuf.next); |}
        else
          p <- FS.readAt f (buf.(lazyFileBuf.offset) + slice.length buf.(lazyFileBuf.next)) 4096;
          if slice.length p == 0
          then LoopRet tt
          else
            newBuf <- Data.sliceAppendSlice buf.(lazyFileBuf.next) p;
            Continue {| lazyFileBuf.offset := buf.(lazyFileBuf.offset);
                        lazyFileBuf.next := newBuf; |}) {| lazyFileBuf.offset := 0;
           lazyFileBuf.next := slice.nil _; |}.

(* RecoverTable restores a table from disk on startup. *)
Definition RecoverTable (p:string) : proc Table.t :=
  index <- Data.newMap uint64;
  f <- FS.open p;
  _ <- readTableIndex f index;
  Ret {| Table.Index := index;
         Table.File := f; |}.

(* CloseTable frees up the fd held by a table. *)
Definition CloseTable (t:Table.t) : proc unit :=
  FS.close t.(Table.File).

Definition readValue (f:File) (off:uint64) : proc (slice.t byte) :=
  startBuf <- FS.readAt f off 512;
  totalBytes <- Data.uint64Get startBuf;
  let buf := slice.skip 8 startBuf in
  let haveBytes := slice.length buf in
  if compare_to haveBytes totalBytes Lt
  then
    buf2 <- FS.readAt f (off + 512) (totalBytes - haveBytes);
    newBuf <- Data.sliceAppendSlice buf buf2;
    Ret newBuf
  else Ret (slice.take totalBytes buf).

Definition tableRead (t:Table.t) (k:uint64) : proc (slice.t byte * bool) :=
  let! (off, ok) <- Data.mapGet t.(Table.Index) k;
  if negb ok
  then Ret (slice.nil _, false)
  else
    p <- readValue t.(Table.File) off;
    Ret (p, true).

Module bufFile.
  Record t := mk {
    file: File;
    buf: ptr (slice.t byte);
  }.
  Global Instance t_zero : HasGoZero t := mk (zeroValue _) (zeroValue _).
End bufFile.

Definition newBuf (f:File) : proc bufFile.t :=
  buf <- Data.newPtr (slice.t byte);
  Ret {| bufFile.file := f;
         bufFile.buf := buf; |}.

Definition bufFlush (f:bufFile.t) : proc unit :=
  buf <- Data.readPtr f.(bufFile.buf);
  if slice.length buf == 0
  then Ret tt
  else
    _ <- FS.append f.(bufFile.file) buf;
    Data.writePtr f.(bufFile.buf) (slice.nil _).

Definition bufAppend (f:bufFile.t) (p:slice.t byte) : proc unit :=
  buf <- Data.readPtr f.(bufFile.buf);
  buf2 <- Data.sliceAppendSlice buf p;
  Data.writePtr f.(bufFile.buf) buf2.

Definition bufClose (f:bufFile.t) : proc unit :=
  _ <- bufFlush f;
  FS.close f.(bufFile.file).

Module tableWriter.
  Record t := mk {
    index: Map uint64;
    name: string;
    file: bufFile.t;
    offset: ptr uint64;
  }.
  Global Instance t_zero : HasGoZero t := mk (zeroValue _) (zeroValue _) (zeroValue _) (zeroValue _).
End tableWriter.

Definition newTableWriter (p:string) : proc tableWriter.t :=
  index <- Data.newMap uint64;
  f <- FS.create p;
  buf <- newBuf f;
  off <- Data.newPtr uint64;
  Ret {| tableWriter.index := index;
         tableWriter.name := p;
         tableWriter.file := buf;
         tableWriter.offset := off; |}.

Definition tableWriterAppend (w:tableWriter.t) (p:slice.t byte) : proc unit :=
  _ <- bufAppend w.(tableWriter.file) p;
  off <- Data.readPtr w.(tableWriter.offset);
  Data.writePtr w.(tableWriter.offset) (off + slice.length p).

Definition tableWriterClose (w:tableWriter.t) : proc Table.t :=
  _ <- bufClose w.(tableWriter.file);
  f <- FS.open w.(tableWriter.name);
  Ret {| Table.Index := w.(tableWriter.index);
         Table.File := f; |}.

(* EncodeUInt64 is an Encoder(uint64) *)
Definition EncodeUInt64 (x:uint64) (p:slice.t byte) : proc (slice.t byte) :=
  tmp <- Data.newSlice byte 8;
  _ <- Data.uint64Put tmp x;
  p2 <- Data.sliceAppendSlice p tmp;
  Ret p2.

(* EncodeSlice is an Encoder([]byte) *)
Definition EncodeSlice (data:slice.t byte) (p:slice.t byte) : proc (slice.t byte) :=
  p2 <- EncodeUInt64 (slice.length data) p;
  p3 <- Data.sliceAppendSlice p2 data;
  Ret p3.

Definition tablePut (w:tableWriter.t) (k:uint64) (v:slice.t byte) : proc unit :=
  tmp <- Data.newSlice byte 0;
  tmp2 <- EncodeUInt64 k tmp;
  tmp3 <- EncodeSlice v tmp2;
  off <- Data.readPtr w.(tableWriter.offset);
  _ <- Data.mapAlter w.(tableWriter.index) k (fun _ => Some (off + slice.length tmp2));
  tableWriterAppend w tmp3.

Module Database.
  (* Database is a handle to an open database. *)
  Record t := mk {
    wbuffer: ptr (Map (slice.t byte));
    rbuffer: ptr (Map (slice.t byte));
    bufferL: LockRef;
    table: ptr Table.t;
    tableName: ptr string;
    tableL: LockRef;
    compactionL: LockRef;
  }.
  Global Instance t_zero : HasGoZero t := mk (zeroValue _) (zeroValue _) (zeroValue _) (zeroValue _) (zeroValue _) (zeroValue _) (zeroValue _).
End Database.

Definition makeValueBuffer  : proc (ptr (Map (slice.t byte))) :=
  buf <- Data.newMap (slice.t byte);
  bufPtr <- Data.newPtr (Map (slice.t byte));
  _ <- Data.writePtr bufPtr buf;
  Ret bufPtr.

(* NewDb initializes a new database on top of an empty filesys. *)
Definition NewDb  : proc Database.t :=
  wbuf <- makeValueBuffer;
  rbuf <- makeValueBuffer;
  bufferL <- Data.newLock;
  let tableName := "table.0" in
  tableNameRef <- Data.newPtr string;
  _ <- Data.writePtr tableNameRef tableName;
  table <- CreateTable tableName;
  tableRef <- Data.newPtr Table.t;
  _ <- Data.writePtr tableRef table;
  tableL <- Data.newLock;
  compactionL <- Data.newLock;
  Ret {| Database.wbuffer := wbuf;
         Database.rbuffer := rbuf;
         Database.bufferL := bufferL;
         Database.table := tableRef;
         Database.tableName := tableNameRef;
         Database.tableL := tableL;
         Database.compactionL := compactionL; |}.

(* Read gets a key from the database.

   Returns a boolean indicating if the k was found and a non-nil slice with
   the value if k was in the database.

   Reflects any completed in-memory writes. *)
Definition Read (db:Database.t) (k:uint64) : proc (slice.t byte * bool) :=
  _ <- Data.lockAcquire db.(Database.bufferL) Reader;
  buf <- Data.readPtr db.(Database.wbuffer);
  let! (v, ok) <- Data.mapGet buf k;
  if ok
  then
    _ <- Data.lockRelease db.(Database.bufferL) Reader;
    Ret (v, true)
  else
    rbuf <- Data.readPtr db.(Database.rbuffer);
    let! (v2, ok) <- Data.mapGet rbuf k;
    if ok
    then
      _ <- Data.lockRelease db.(Database.bufferL) Reader;
      Ret (v2, true)
    else
      _ <- Data.lockAcquire db.(Database.tableL) Reader;
      tbl <- Data.readPtr db.(Database.table);
      let! (v3, ok) <- tableRead tbl k;
      _ <- Data.lockRelease db.(Database.tableL) Reader;
      _ <- Data.lockRelease db.(Database.bufferL) Reader;
      Ret (v3, ok).

(* Write sets a key to a new value.

   Creates a new key-value mapping if k is not in the database and overwrites
   the previous value if k is present.

   The new value is buffered in memory. To persist it, call db.Compact(). *)
Definition Write (db:Database.t) (k:uint64) (v:slice.t byte) : proc unit :=
  _ <- Data.lockAcquire db.(Database.bufferL) Writer;
  buf <- Data.readPtr db.(Database.wbuffer);
  _ <- Data.mapAlter buf k (fun _ => Some v);
  Data.lockRelease db.(Database.bufferL) Writer.

Definition freshTable (p:string) : proc string :=
  if p == "table.0"
  then Ret "table.1"
  else
    if p == "table.1"
    then Ret "table.0"
    else Ret p.

Definition tablePutBuffer (w:tableWriter.t) (buf:Map (slice.t byte)) : proc unit :=
  Data.mapIter buf (fun k v =>
    tablePut w k v).

(* add all of table t to the table w being created; skip any keys in the (read)
   buffer b since those writes overwrite old ones *)
Definition tablePutOldTable (w:tableWriter.t) (t:Table.t) (b:Map (slice.t byte)) : proc unit :=
  Loop (fun buf =>
        let! (e, l) <- DecodeEntry buf.(lazyFileBuf.next);
        if compare_to l 0 Gt
        then
          let! (_, ok) <- Data.mapGet b e.(Entry.Key);
          _ <- if negb ok
          then tablePut w e.(Entry.Key) e.(Entry.Value)
          else Ret tt;
          Continue {| lazyFileBuf.offset := buf.(lazyFileBuf.offset) + l;
                      lazyFileBuf.next := slice.skip l buf.(lazyFileBuf.next); |}
        else
          p <- FS.readAt t.(Table.File) (buf.(lazyFileBuf.offset) + slice.length buf.(lazyFileBuf.next)) 4096;
          if slice.length p == 0
          then LoopRet tt
          else
            newBuf <- Data.sliceAppendSlice buf.(lazyFileBuf.next) p;
            Continue {| lazyFileBuf.offset := buf.(lazyFileBuf.offset);
                        lazyFileBuf.next := newBuf; |}) {| lazyFileBuf.offset := 0;
           lazyFileBuf.next := slice.nil _; |}.

(* Build a new shadow table that incorporates the current table and a
   (write) buffer wbuf.

   Assumes all the appropriate locks have been taken.

   Returns the old table and new table. *)
Definition constructNewTable (db:Database.t) (wbuf:Map (slice.t byte)) : proc (Table.t * Table.t) :=
  oldName <- Data.readPtr db.(Database.tableName);
  name <- freshTable oldName;
  w <- newTableWriter name;
  oldTable <- Data.readPtr db.(Database.table);
  _ <- tablePutOldTable w oldTable wbuf;
  _ <- tablePutBuffer w wbuf;
  newTable <- tableWriterClose w;
  Ret (oldTable, newTable).

(* Compact persists in-memory writes to a new table.

   This simple database design must re-write all data to combine in-memory
   writes with existing writes. *)
Definition Compact (db:Database.t) : proc unit :=
  _ <- Data.lockAcquire db.(Database.compactionL) Writer;
  _ <- Data.lockAcquire db.(Database.bufferL) Writer;
  buf <- Data.readPtr db.(Database.wbuffer);
  emptyWbuffer <- Data.newMap (slice.t byte);
  _ <- Data.writePtr db.(Database.wbuffer) emptyWbuffer;
  _ <- Data.writePtr db.(Database.rbuffer) buf;
  _ <- Data.lockRelease db.(Database.bufferL) Writer;
  _ <- Data.lockAcquire db.(Database.tableL) Reader;
  oldTableName <- Data.readPtr db.(Database.tableName);
  let! (oldTable, t) <- constructNewTable db buf;
  newTable <- freshTable oldTableName;
  _ <- Data.lockRelease db.(Database.tableL) Reader;
  _ <- Data.lockAcquire db.(Database.tableL) Writer;
  _ <- Data.writePtr db.(Database.table) t;
  _ <- Data.writePtr db.(Database.tableName) newTable;
  manifestData <- Data.stringToBytes newTable;
  _ <- FS.atomicCreate "manifest" manifestData;
  _ <- CloseTable oldTable;
  _ <- FS.delete oldTableName;
  _ <- Data.lockRelease db.(Database.tableL) Writer;
  Data.lockRelease db.(Database.compactionL) Writer.

Definition recoverManifest  : proc string :=
  f <- FS.open "manifest";
  manifestData <- FS.readAt f 0 4096;
  tableName <- Data.bytesToString manifestData;
  _ <- FS.close f;
  Ret tableName.

(* delete 'name' if it isn't tableName or "manifest" *)
Definition deleteOtherFile (name:string) (tableName:string) : proc unit :=
  if name == tableName
  then Ret tt
  else
    if name == "manifest"
    then Ret tt
    else FS.delete name.

Definition deleteOtherFiles (tableName:string) : proc unit :=
  files <- FS.list;
  let nfiles := slice.length files in
  Loop (fun i =>
        if i == nfiles
        then LoopRet tt
        else
          name <- Data.sliceRead files i;
          _ <- deleteOtherFile name tableName;
          Continue (i + 1)) 0.

(* Recover restores a previously created database after a crash or shutdown. *)
Definition Recover  : proc Database.t :=
  tableName <- recoverManifest;
  table <- RecoverTable tableName;
  tableRef <- Data.newPtr Table.t;
  _ <- Data.writePtr tableRef table;
  tableNameRef <- Data.newPtr string;
  _ <- Data.writePtr tableNameRef tableName;
  _ <- deleteOtherFiles tableName;
  wbuffer <- makeValueBuffer;
  rbuffer <- makeValueBuffer;
  bufferL <- Data.newLock;
  tableL <- Data.newLock;
  compactionL <- Data.newLock;
  Ret {| Database.wbuffer := wbuffer;
         Database.rbuffer := rbuffer;
         Database.bufferL := bufferL;
         Database.table := tableRef;
         Database.tableName := tableNameRef;
         Database.tableL := tableL;
         Database.compactionL := compactionL; |}.

(* Shutdown immediately closes the database.

   Discards any uncommitted in-memory writes; similar to a crash except for
   cleanly closing any open files. *)
Definition Shutdown (db:Database.t) : proc unit :=
  _ <- Data.lockAcquire db.(Database.bufferL) Writer;
  _ <- Data.lockAcquire db.(Database.compactionL) Writer;
  t <- Data.readPtr db.(Database.table);
  _ <- CloseTable t;
  _ <- Data.lockRelease db.(Database.compactionL) Writer;
  Data.lockRelease db.(Database.bufferL) Writer.

(* Close closes an open database cleanly, flushing any in-memory writes.

   db should not be used afterward *)
Definition Close (db:Database.t) : proc unit :=
  _ <- Compact db;
  Shutdown db.