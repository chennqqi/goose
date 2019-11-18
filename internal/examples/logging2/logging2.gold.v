(* autogenerated from logging2 *)
From Perennial.go_lang Require Import prelude.

(* disk FFI *)
From Perennial.go_lang Require Import ffi.disk_prelude.

Definition LOGCOMMIT : expr := #0.

Definition LOGSTART : expr := #1.

Definition LOGMAXBLK : expr := #510.

Definition LOGEND : expr := "LOGMAXBLK" + "LOGSTART".

Module Log.
  Definition S := struct.new [
    "logLock" :: lockRefT;
    "memLock" :: lockRefT;
    "logSz" :: intT;
    "memLog" :: refT (slice.T disk.blockT);
    "memLen" :: refT intT;
    "memTxnNxt" :: refT intT;
    "logTxnNxt" :: refT intT
  ].
  Definition T: ty := struct.t S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
  End fields.
End Log.

Definition Log__writeHdr: val :=
  λ: "log" "len",
    let: "hdr" := NewSlice byteT #4096 in
    UInt64Put "hdr" "len";;
    disk.Write "LOGCOMMIT" "hdr".

Definition Init: val :=
  λ: "logSz",
    let: "log" := struct.mk Log.S [
      "logLock" ::= Data.newLock #();
      "memLock" ::= Data.newLock #();
      "logSz" ::= "logSz";
      "memLog" ::= ref (zero_val (slice.T disk.blockT));
      "memLen" ::= ref (zero_val intT);
      "memTxnNxt" ::= ref (zero_val intT);
      "logTxnNxt" ::= ref (zero_val intT)
    ] in
    Log__writeHdr "log" #0;;
    "log".

Definition Log__readHdr: val :=
  λ: "log",
    let: "hdr" := disk.Read "LOGCOMMIT" in
    let: "disklen" := UInt64Get "hdr" in
    "disklen".

Definition Log__readBlocks: val :=
  λ: "log" "len",
    let: "blks" := ref (NewSlice disk.blockT #0) in
    let: "i" := ref #0 in
    for: (!"i" < "len"); ("i" <- !"i" + #1) :=
      let: "blk" := disk.Read ("LOGSTART" + !"i") in
      "blks" <- SliceAppend !"blks" "blk";;
      Continue;;
    !"blks".

Definition Log__Read: val :=
  λ: "log",
    Data.lockAcquire Writer (Log.get "logLock" "log");;
    let: "disklen" := Log__readHdr "log" in
    let: "blks" := Log__readBlocks "log" "disklen" in
    Data.lockRelease Writer (Log.get "logLock" "log");;
    "blks".

Definition Log__memWrite: val :=
  λ: "log" "l",
    let: "n" := slice.len "l" in
    let: "i" := ref #0 in
    for: (!"i" < "n"); ("i" <- !"i" + #1) :=
      Log.get "memLog" "log" <- SliceAppend (!(Log.get "memLog" "log")) (SliceGet "l" !"i");;
      Continue.

Definition Log__memAppend: val :=
  λ: "log" "l",
    Data.lockAcquire Writer (Log.get "memLock" "log");;
    if: !(Log.get "memLen" "log") + slice.len "l" ≥ Log.get "logSz" "log"
    then
      Data.lockRelease Writer (Log.get "memLock" "log");;
      (#false, #0)
    else
      let: "txn" := !(Log.get "memTxnNxt" "log") in
      let: "n" := !(Log.get "memLen" "log") + slice.len "l" in
      Log.get "memLen" "log" <- "n";;
      Log.get "memTxnNxt" "log" <- !(Log.get "memTxnNxt" "log") + #1;;
      Data.lockRelease Writer (Log.get "memLock" "log");;
      (#true, "txn").

(* XXX just an atomic read? *)
Definition Log__readLogTxnNxt: val :=
  λ: "log",
    Data.lockAcquire Writer (Log.get "memLock" "log");;
    let: "n" := !(Log.get "logTxnNxt" "log") in
    Data.lockRelease Writer (Log.get "memLock" "log");;
    "n".

Definition Log__diskAppendWait: val :=
  λ: "log" "txn",
    Skip;;
    for: (#true); (Skip) :=
      let: "logtxn" := Log__readLogTxnNxt "log" in
      if: "txn" < "logtxn"
      then Break
      else Continue.

Definition Log__Append: val :=
  λ: "log" "l",
    let: ("ok", "txn") := Log__memAppend "log" "l" in
    if: "ok"
    then
      Log__diskAppendWait "log" "txn";;
      #()
    else #();;
    "ok".

Definition Log__writeBlocks: val :=
  λ: "log" "l" "pos",
    let: "n" := slice.len "l" in
    let: "i" := ref #0 in
    for: (!"i" < "n"); ("i" <- !"i" + #1) :=
      let: "bk" := SliceGet "l" !"i" in
      disk.Write ("pos" + !"i") "bk";;
      Continue.

Definition Log__diskAppend: val :=
  λ: "log",
    Data.lockAcquire Writer (Log.get "logLock" "log");;
    let: "disklen" := Log__readHdr "log" in
    Data.lockAcquire Writer (Log.get "memLock" "log");;
    let: "memlen" := !(Log.get "memLen" "log") in
    let: "allblks" := !(Log.get "memLog" "log") in
    let: "blks" := SliceSkip "allblks" "disklen" in
    let: "memnxt" := !(Log.get "memTxnNxt" "log") in
    Data.lockRelease Writer (Log.get "memLock" "log");;
    Log__writeBlocks "log" "blks" "disklen";;
    Log__writeHdr "log" "memlen";;
    Log.get "logTxnNxt" "log" <- "memnxt";;
    Data.lockRelease Writer (Log.get "logLock" "log").

Definition Log__Logger: val :=
  λ: "log",
    Skip;;
    for: (#true); (Skip) :=
      Log__diskAppend "log";;
      Continue.

Module Txn.
  Definition S := struct.new [
    "log" :: refT Log.T;
    "blks" :: refT (mapT disk.blockT)
  ].
  Definition T: ty := struct.t S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
  End fields.
End Txn.

(* XXX wait if cannot reserve space in log *)
Definition Begin: val :=
  λ: "log",
    let: "txn" := struct.mk Txn.S [
      "log" ::= "log";
      "blks" ::= ref (zero_val (mapT disk.blockT))
    ] in
    "txn".

Definition Txn__Write: val :=
  λ: "txn" "addr" "blk",
    let: (<>, "ok") := MapGet (!(Txn.get "blks" "txn")) "addr" in
    if: "ok"
    then
      MapInsert (!(Txn.get "blks" "txn")) "addr" !"blk";;
      #()
    else #();;
    if: ~ "ok"
    then
      if: "addr" = "LOGMAXBLK"
      then #false
      else MapInsert (!(Txn.get "blks" "txn")) "addr" !"blk";;
      #()
    else #();;
    #true.

Definition Txn__Read: val :=
  λ: "txn" "addr",
    let: ("v", "ok") := MapGet (!(Txn.get "blks" "txn")) "addr" in
    if: "ok"
    then "v"
    else disk.Read ("addr" + "LOGEND").

Definition Txn__Commit: val :=
  λ: "txn",
    let: "blks" := ref (zero_val (slice.T disk.blockT)) in
    Data.mapIter !(Txn.get "blks" "txn") (λ: <> "v",
      "blks" <- SliceAppend !"blks" "v");;
    let: "ok" := Log__Append (!(Txn.get "log" "txn")) !"blks" in
    "ok".
