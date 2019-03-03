From RecoveryRefinement.Goose Require Import base.

Module importantStruct.
  (* This struct is very important.

     This is despite it being empty. *)
  Record t := mk {
  }.
  Global Instance t_zero : HasGoZero t := mk .
End importantStruct.

(* doSubtleThings does a number of subtle things:

   (actually, it does nothing) *)
Definition doSubtleThings  : proc unit :=
  Ret tt.

Definition typedLiteral  : proc uint64 :=
  Ret 3.

Definition literalCast  : proc uint64 :=
  let x := 2 in
  Ret (x + 2).

Definition castInt (p:slice.t byte) : proc uint64 :=
  Ret (slice.length p).

Definition stringToByteSlice (s:string) : proc (slice.t byte) :=
  p <- Data.stringToBytes s;
  Ret p.

Definition byteSliceToString (p:slice.t byte) : proc string :=
  s <- Data.bytesToString p;
  Ret s.

Definition useSlice  : proc unit :=
  s <- Data.newSlice byte 1;
  s1 <- Data.sliceAppendSlice s s;
  FS.atomicCreate "file" s1.

Definition useSliceIndexing  : proc uint64 :=
  s <- Data.newSlice uint64 2;
  _ <- Data.sliceWrite s 1 2;
  x <- Data.sliceRead s 0;
  Ret x.

Definition useMap  : proc unit :=
  m <- Data.newMap (slice.t byte);
  _ <- Data.mapAlter m 1 (fun _ => Some (slice.nil _));
  let! (x, ok) <- Data.mapGet m 2;
  if ok
  then Ret tt
  else Data.mapAlter m 3 (fun _ => Some x).

Definition usePtr  : proc unit :=
  p <- Data.newPtr uint64;
  _ <- Data.writePtr p 1;
  x <- Data.readPtr p;
  Data.writePtr p x.

Definition iterMapKeysAndValues (m:Map uint64) : proc uint64 :=
  sumPtr <- Data.newPtr uint64;
  _ <- Data.mapIter m (fun k v =>
    sum <- Data.readPtr sumPtr;
    Data.writePtr sumPtr (sum + k + v));
  sum <- Data.readPtr sumPtr;
  Ret sum.

Definition iterMapKeys (m:Map uint64) : proc (slice.t uint64) :=
  keysSlice <- Data.newSlice uint64 0;
  keysRef <- Data.newPtr (slice.t uint64);
  _ <- Data.writePtr keysRef keysSlice;
  _ <- Data.mapIter m (fun k _ =>
    keys <- Data.readPtr keysRef;
    newKeys <- Data.sliceAppend keys k;
    Data.writePtr keysRef newKeys);
  keys <- Data.readPtr keysRef;
  Ret keys.

Definition getRandom  : proc uint64 :=
  r <- Data.randomUint64;
  Ret r.

Definition empty  : proc unit :=
  Ret tt.

Definition emptyReturn  : proc unit :=
  Ret tt.

Module allTheLiterals.
  Record t := mk {
    int: uint64;
    s: string;
    b: bool;
  }.
  Global Instance t_zero : HasGoZero t := mk (zeroValue _) (zeroValue _) (zeroValue _).
End allTheLiterals.

Definition normalLiterals  : proc allTheLiterals.t :=
  Ret {| allTheLiterals.int := 0;
         allTheLiterals.s := "foo";
         allTheLiterals.b := true; |}.

Definition specialLiterals  : proc allTheLiterals.t :=
  Ret {| allTheLiterals.int := 4096;
         allTheLiterals.s := "";
         allTheLiterals.b := false; |}.

Definition oddLiterals  : proc allTheLiterals.t :=
  Ret {| allTheLiterals.int := 5;
         allTheLiterals.s := "backquote string";
         allTheLiterals.b := false; |}.

(* DoSomething is an impure function *)
Definition DoSomething (s:string) : proc unit :=
  Ret tt.

Definition conditionalInLoop  : proc unit :=
  Loop (fun i =>
        _ <- if compare_to i 3 Lt
        then DoSomething ("i is small")
        else Ret tt;
        if compare_to i 5 Gt
        then LoopRet tt
        else Continue (i + 1)) 0.

Definition returnTwo (p:slice.t byte) : proc (uint64 * uint64) :=
  Ret (0, 0).

Definition returnTwoWrapper (data:slice.t byte) : proc (uint64 * uint64) :=
  let! (a, b) <- returnTwo data;
  Ret (a, b).

(* Skip is a placeholder for some impure code *)
Definition Skip  : proc unit :=
  Ret tt.

Definition simpleSpawn  : proc unit :=
  l <- Data.newLock;
  v <- Data.newPtr uint64;
  _ <- Spawn (_ <- Data.lockAcquire l Reader;
         x <- Data.readPtr v;
         _ <- if compare_to x 0 Gt
         then Skip
         else Ret tt;
         Data.lockRelease l Reader);
  _ <- Data.lockAcquire l Writer;
  _ <- Data.writePtr v 1;
  Data.lockRelease l Writer.

Definition threadCode (tid:uint64) : proc unit :=
  Ret tt.

Definition loopSpawn  : proc unit :=
  _ <- Loop (fun i =>
        if compare_to i 10 Gt
        then LoopRet tt
        else
          _ <- Spawn (threadCode i);
          Continue (i + 1)) 0;
  Loop (fun dummy =>
        Continue dummy) true.

Definition stringAppend (s:string) (x:uint64) : proc string :=
  Ret ("prefix " ++ s ++ " " ++ uint64_to_string x).

(* DoSomeLocking uses the entire lock API *)
Definition DoSomeLocking (l:LockRef) : proc unit :=
  _ <- Data.lockAcquire l Writer;
  _ <- Data.lockRelease l Writer;
  _ <- Data.lockAcquire l Reader;
  _ <- Data.lockAcquire l Reader;
  _ <- Data.lockRelease l Reader;
  Data.lockRelease l Reader.

Definition makeLock  : proc unit :=
  l <- Data.newLock;
  DoSomeLocking l.