(* autogenerated from unittest *)
From Perennial.go_lang Require Import prelude.

(* disk FFI *)
From Perennial.go_lang Require Import ffi.disk_prelude.

Module importantStruct.
  (* This struct is very important.

     This is despite it being empty. *)
  Definition S := struct.decl [
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End importantStruct.

(* doSubtleThings does a number of subtle things:

   (actually, it does nothing) *)
Definition doSubtleThings: val :=
  λ: <>,
    #().

Definition GlobalConstant : expr := #(str"foo").

(* an untyped string *)
Definition UntypedStringConstant : expr := #(str"bar").

Definition TypedInt : expr := #32.

Definition ConstWithArith : expr := #4 + #3 * TypedInt.

Definition typedLiteral: val :=
  λ: <>,
    #3.

Definition literalCast: val :=
  λ: <>,
    let: "x" := #2 in
    "x" + #2.

Definition castInt: val :=
  λ: "p",
    slice.len "p".

Definition stringToByteSlice: val :=
  λ: "s",
    let: "p" := Data.stringToBytes "s" in
    "p".

Definition byteSliceToString: val :=
  λ: "p",
    let: "s" := Data.bytesToString "p" in
    "s".

Definition useSlice: val :=
  λ: <>,
    let: "s" := NewSlice byteT #1 in
    let: "s1" := Data.sliceAppendSlice "s" "s" in
    FS.atomicCreate #(str"dir") #(str"file") "s1".

Definition useSliceIndexing: val :=
  λ: <>,
    let: "s" := NewSlice uint64T #2 in
    SliceSet "s" #1 #2;;
    let: "x" := SliceGet "s" #0 in
    "x".

Definition useMap: val :=
  λ: <>,
    let: "m" := NewMap (slice.T byteT) in
    MapInsert "m" #1 slice.nil;;
    let: ("x", "ok") := MapGet "m" #2 in
    (if: "ok"
    then "tt"
    else MapInsert "m" #3 "x").

Definition usePtr: val :=
  λ: <>,
    let: "p" := ref (zero_val uint64T) in
    "p" <- #1;;
    let: "x" := !"p" in
    "p" <- "x".

Definition iterMapKeysAndValues: val :=
  λ: "m",
    let: "sumPtr" := ref (zero_val uint64T) in
    Data.mapIter "m" (λ: "k" "v",
      let: "sum" := !"sumPtr" in
      "sumPtr" <- "sum" + "k" + "v");;
    let: "sum" := !"sumPtr" in
    "sum".

Definition iterMapKeys: val :=
  λ: "m",
    let: "keysSlice" := NewSlice uint64T #0 in
    let: "keysRef" := ref (zero_val (slice.T uint64T)) in
    "keysRef" <- "keysSlice";;
    Data.mapIter "m" (λ: "k" <>,
      let: "keys" := !"keysRef" in
      let: "newKeys" := SliceAppend "keys" "k" in
      "keysRef" <- "newKeys");;
    let: "keys" := !"keysRef" in
    "keys".

Definition getRandom: val :=
  λ: <>,
    let: "r" := Data.randomUint64 #() in
    "r".

Definition empty: val :=
  λ: <>,
    #().

Definition emptyReturn: val :=
  λ: <>,
    "tt".

Module allTheLiterals.
  Definition S := struct.decl [
    "int" :: uint64T;
    "s" :: stringT;
    "b" :: boolT
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End allTheLiterals.

Definition normalLiterals: val :=
  λ: <>,
    struct.mk allTheLiterals.S [
      "int" ::= #0;
      "s" ::= #(str"foo");
      "b" ::= #true
    ].

Definition specialLiterals: val :=
  λ: <>,
    struct.mk allTheLiterals.S [
      "int" ::= #4096;
      "s" ::= #(str"");
      "b" ::= #false
    ].

Definition oddLiterals: val :=
  λ: <>,
    struct.mk allTheLiterals.S [
      "int" ::= #5;
      "s" ::= #(str"backquote string");
      "b" ::= #false
    ].

(* DoSomething is an impure function *)
Definition DoSomething: val :=
  λ: "s",
    #().

Definition standardForLoop: val :=
  λ: "s",
    let: "sumPtr" := ref (zero_val uint64T) in
    let: "i" := ref #0 in
    (for: (#true); (Skip) :=
      (if: !"i" < slice.len "s"
      then
        let: "sum" := !"sumPtr" in
        let: "x" := SliceGet "s" !"i" in
        "sumPtr" <- "sum" + "x";;
        "i" <- !"i" + #1;;
        Continue
      else Break));;
    let: "sum" := !"sumPtr" in
    "sum".

Definition conditionalInLoop: val :=
  λ: <>,
    let: "i" := ref #0 in
    (for: (#true); (Skip) :=
      (if: !"i" < #3
      then
        DoSomething (#(str"i is small"));;
        #()
      else #());;
      (if: !"i" > #5
      then Break
      else
        "i" <- !"i" + #1;;
        Continue)).

Definition clearMap: val :=
  λ: "m",
    Data.mapClear "m".

Definition IterateMapKeys: val :=
  λ: "m" "sum",
    Data.mapIter "m" (λ: "k" <>,
      let: "oldSum" := !"sum" in
      "sum" <- "oldSum" + "k").

Definition returnTwo: val :=
  λ: "p",
    (#0, #0).

Definition returnTwoWrapper: val :=
  λ: "data",
    let: ("a", "b") := returnTwo "data" in
    ("a", "b").

Definition PanicAtTheDisco: val :=
  λ: <>,
    Panic "disco".

Module composite.
  Definition S := struct.decl [
    "a" :: uint64T;
    "b" :: uint64T
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End composite.

Definition ReassignVars: val :=
  λ: <>,
    let: "x" := zero_val uint64T in
    let: "y" := #0 in
    "x" <- #3;;
    let: "z" := ref (struct.mk composite.S [
      "a" ::= !"x";
      "b" ::= "y"
    ]) in
    "z" <- struct.mk composite.S [
      "a" ::= "y";
      "b" ::= !"x"
    ];;
    "x" <- composite.get "a" !"z".

Module Block.
  Definition S := struct.decl [
    "Value" :: uint64T
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End Block.

Definition Disk1 : expr := #0.

Definition Disk2 : expr := #0.

Definition DiskSize : expr := #1000.

(* TwoDiskWrite is a dummy function to represent the base layer's disk write *)
Definition TwoDiskWrite: val :=
  λ: "diskId" "a" "v",
    #true.

(* TwoDiskRead is a dummy function to represent the base layer's disk read *)
Definition TwoDiskRead: val :=
  λ: "diskId" "a",
    (struct.mk Block.S [
       "Value" ::= #0
     ], #true).

(* TwoDiskLock is a dummy function to represent locking an address in the
   base layer *)
Definition TwoDiskLock: val :=
  λ: "a",
    #().

(* TwoDiskUnlock is a dummy function to represent unlocking an address in the
   base layer *)
Definition TwoDiskUnlock: val :=
  λ: "a",
    #().

Definition ReplicatedDiskRead: val :=
  λ: "a",
    TwoDiskLock "a";;
    let: ("v", "ok") := TwoDiskRead Disk1 "a" in
    (if: "ok"
    then
      TwoDiskUnlock "a";;
      "v"
    else
      let: ("v2", <>) := TwoDiskRead Disk2 "a" in
      TwoDiskUnlock "a";;
      "v2").

Definition ReplicatedDiskWrite: val :=
  λ: "a" "v",
    TwoDiskLock "a";;
    TwoDiskWrite Disk1 "a" "v";;
    TwoDiskWrite Disk2 "a" "v";;
    TwoDiskUnlock "a".

Definition ReplicatedDiskRecover: val :=
  λ: <>,
    let: "a" := ref #0 in
    (for: (#true); (Skip) :=
      (if: !"a" > DiskSize
      then Break
      else
        let: ("v", "ok") := TwoDiskRead Disk1 !"a" in
        (if: "ok"
        then
          TwoDiskWrite Disk2 !"a" "v";;
          #()
        else #());;
        "a" <- !"a" + #1;;
        Continue)).

Definition sliceOps: val :=
  λ: <>,
    let: "x" := NewSlice uint64T #10 in
    let: "v1" := SliceGet "x" #2 in
    let: "v2" := SliceSubslice "x" #2 #3 in
    let: "v3" := SliceTake "x" #3 in
    let: "v4" := SliceRef "x" #2 in
    "v1" + SliceGet "v2" #0 + SliceGet "v3" #1 + !"v4".

Module thing.
  Definition S := struct.decl [
    "x" :: uint64T
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End thing.

Module sliceOfThings.
  Definition S := struct.decl [
    "things" :: slice.T thing.T
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End sliceOfThings.

Definition sliceOfThings__getThingRef: val :=
  λ: "ts" "i",
    SliceRef (sliceOfThings.get "things" "ts") "i".

(* Skip is a placeholder for some impure code *)
Definition Skip: val :=
  λ: <>,
    #().

Definition simpleSpawn: val :=
  λ: <>,
    let: "l" := Data.newLock #() in
    let: "v" := ref (zero_val uint64T) in
    Fork (Data.lockAcquire Reader "l";;
          let: "x" := !"v" in
          (if: "x" > #0
          then
            Skip #();;
            #()
          else #());;
          Data.lockRelease Reader "l");;
    Data.lockAcquire Writer "l";;
    "v" <- #1;;
    Data.lockRelease Writer "l".

Definition threadCode: val :=
  λ: "tid",
    #().

Definition loopSpawn: val :=
  λ: <>,
    let: "i" := ref #0 in
    (for: (!"i" < #10); ("i" <- !"i" + #1) :=
      let: "i" := !"i" in
      Fork (threadCode "i");;
      Continue);;
    let: "dummy" := ref #true in
    (for: (#true); (Skip) :=
      "dummy" <- ~ !"dummy";;
      Continue).

Definition stringAppend: val :=
  λ: "s" "x",
    #(str"prefix ") + "s" + #(str" ") + uint64_to_string "x".

Module C.
  Definition S := struct.decl [
    "x" :: uint64T;
    "y" :: uint64T
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End C.

Definition C__Add: val :=
  λ: "c" "z",
    C.get "x" "c" + C.get "y" "c" + "z".

Definition C__GetField: val :=
  λ: "c",
    let: "x" := C.get "x" "c" in
    let: "y" := C.get "y" "c" in
    "x" + "y".

Definition UseAdd: val :=
  λ: <>,
    let: "c" := struct.mk C.S [
      "x" ::= #2;
      "y" ::= #3
    ] in
    let: "r" := C__Add "c" #4 in
    "r".

Definition UseAddWithLiteral: val :=
  λ: <>,
    let: "r" := C__Add (struct.mk C.S [
      "x" ::= #2;
      "y" ::= #3
    ]) #4 in
    "r".

Module TwoInts.
  Definition S := struct.decl [
    "x" :: uint64T;
    "y" :: uint64T
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End TwoInts.

Module S.
  Definition S := struct.decl [
    "a" :: uint64T;
    "b" :: TwoInts.T;
    "c" :: boolT
  ].
  Definition T: ty := struct.t S.
  Definition Ptr: ty := struct.ptrT S.
  Section fields.
    Context `{ext_ty: ext_types}.
    Definition get := struct.get S.
    Definition loadF := struct.loadF S.
  End fields.
End S.

Definition NewS: val :=
  λ: <>,
    struct.new S.S [
      "a" ::= #2;
      "b" ::= struct.mk TwoInts.S [
        "x" ::= #1;
        "y" ::= #2
      ];
      "c" ::= #true
    ].

Definition S__readA: val :=
  λ: "s",
    S.loadF "a" "s".

Definition S__readB: val :=
  λ: "s",
    S.loadF "b" "s".

Definition S__readBVal: val :=
  λ: "s",
    S.get "b" "s".

Definition S__writeB: val :=
  λ: "s" "two",
    struct.storeF S.S "b" "s" "two".

Definition S__negateC: val :=
  λ: "s",
    struct.storeF S.S "c" "s" (~ (S.loadF "c" "s")).

(* DoSomeLocking uses the entire lock API *)
Definition DoSomeLocking: val :=
  λ: "l",
    Data.lockAcquire Writer "l";;
    Data.lockRelease Writer "l";;
    Data.lockAcquire Reader "l";;
    Data.lockAcquire Reader "l";;
    Data.lockRelease Reader "l";;
    Data.lockRelease Reader "l".

Definition makeLock: val :=
  λ: <>,
    let: "l" := Data.newLock #() in
    DoSomeLocking "l".

Definition u64: ty := uint64T.

Definition Timestamp: ty := uint64T.

Definition UseTypeAbbrev: ty := u64.

Definition UseNamedType: ty := Timestamp.
