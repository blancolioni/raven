with Raven.Instructions;

private package Raven.Objects is

   function Nil return Object
     with Post => not Is_Truthy (Nil'Result);

   function Undefined return Object
     with Post => not Is_Truthy (Undefined'Result);

   function Pending return Object;

   --  What a port answers with when there is nothing left to read.
   --  R7RS says it is one object, distinct from everything else, and
   --  a constant is what that is.

   function Eof return Object;
   function Is_Eof (X : Object) return Boolean;

   function Lambda return Object;

   --  The procedure call/cc is written on (#47).  It is the machine's:
   --  applying it captures the machine's registers, which no procedure
   --  written in scheme or bound by a host can reach.

   function Call_CC return Object;

   function Cond return Object;
   function Define return Object;
   function If_Obj return Object;
   function Quote return Object;

   function To_Object (B : Boolean) return Object
     with Post => Is_Truthy (To_Object'Result) = B;

   function Is_Truthy (X : Object) return Boolean;

   --  Integer is tag 0 and float is tag 1, so the two numeric tags
   --  differ only in the low bit and asking whether something is a
   --  number at all is one mask and one compare over both.

   function Is_Number (X : Object) return Boolean;

   --  The integers an object holds: the payload and a sign, which is
   --  29 bits of magnitude.  What is past them is not an integer raven
   --  has, and arithmetic and the reader both say so rather than
   --  answering with a different number.

   Max_Integer : constant := 2 ** (Object_Payload_Bits - 1) - 1;
   Min_Integer : constant := -2 ** (Object_Payload_Bits - 1);

   function Is_Integer (X : Object) return Boolean;
   function To_Integer (X : Object) return Integer
     with Pre => Is_Integer (X);
   function To_Object (I : Integer) return Object
     with Pre  => I in Min_Integer .. Max_Integer,
          Post => Is_Integer (To_Object'Result)
                  and then To_Integer (To_Object'Result) = I;

   --  The floats raven holds are one sign bit, six of exponent and
   --  twenty three of significand.  That is IEEE single's precision
   --  exactly -- every mantissa bit of a single is kept -- with a
   --  shorter exponent, so what a single has and this does not is
   --  range rather than accuracy: 2**-30 up to just short of 2**32.
   --
   --  Which is why this asks first.  The encoding used to mask the low
   --  bits of a single off to make room for the tag while promising
   --  the round trip below, so a float whose last bits were not zero
   --  broke the promise and 0.1 could not be read at all.  Nothing is
   --  masked now: a number that does not fit is not a float raven has,
   --  and saying so is the reader's job.

   function Is_Float (X : Object) return Boolean;
   function Is_Representable (F : Float) return Boolean;
   function To_Float (X : Object) return Float
     with Pre => Is_Float (X);
   function To_Object (F : Float) return Object
     with Pre  => Is_Representable (F),
     Post => Is_Float (To_Object'Result)
     and then To_Float (To_Object'Result) = F;

   --  An inexact number is a double (#103): arithmetic on one is done in
   --  Long_Float, and the answer is kept as the immediate float above
   --  when that holds it exactly -- 1.5, 0.25, 1000.0 -- and otherwise
   --  as a boxed double in the heap.  Which is #100's rule for numbers,
   --  applied to these: the smallest representation that holds it.
   --
   --  A boxed double is a block laid out as a bignum's is, a header and
   --  then the eight bytes of the double, packed.

   function Fits_Immediate (X : Long_Float) return Boolean;

   --  An exact rational that is not an integer (#104): one cell, its car
   --  the numerator and its cdr the denominator, each an exact integer
   --  object -- a fixnum or a bignum.  It is always in lowest terms with
   --  a positive denominator, and never has a denominator of one, which
   --  would be an integer: normalisation (#100) sees to all three.  The
   --  collector copies it as it copies a pair and traces both halves, as
   --  it does a closure's.

   --  Several values, as values answers them (#48): one cell whose car
   --  is the list of them.  It is not a pair, so a program cannot take
   --  it for a list, and call-with-values is what takes it apart.  One
   --  value is never one of these; it is the value.

   --  A continuation (#47): one cell whose car is the list of the
   --  machine's four registers as they were when it was captured, and
   --  how deep in runs of the machine it was.  Applying one puts them
   --  back.

   function Is_Continuation (X : Object) return Boolean;
   function To_Continuation (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Continuation (To_Continuation'Result)
     and then Has_Address (To_Continuation'Result)
     and then Get_Address (To_Continuation'Result) = Address;

   function Is_Values (X : Object) return Boolean;
   function To_Values (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Values (To_Values'Result)
     and then Has_Address (To_Values'Result)
     and then Get_Address (To_Values'Result) = Address;

   function Is_Ratnum (X : Object) return Boolean;
   function To_Ratnum (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Ratnum (To_Ratnum'Result)
     and then Has_Address (To_Ratnum'Result)
     and then Get_Address (To_Ratnum'Result) = Address;

   function Is_Flonum (X : Object) return Boolean;
   function To_Flonum (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Flonum (To_Flonum'Result)
     and then Has_Address (To_Flonum'Result)
     and then Get_Address (To_Flonum'Result) = Address;

   --  A character is a code point, and Unicode's last one is
   --  16#10FFFF#, which wants twenty one bits and has twenty four.
   --  Ada's Wide_Wide_Character goes to 2**31 - 1, which is not a code
   --  point and never fitted in a payload of any width raven has had:
   --  the round trip below could be asked of one and could not keep
   --  it.  So the limit is written where the encoding is, and every
   --  caller inherits it.

   subtype Character_Value is Wide_Wide_Character
     range Wide_Wide_Character'Val (0)
        .. Wide_Wide_Character'Val (16#10FFFF#);

   function Is_Character (X : Object) return Boolean;
   function To_Character (X : Object) return Character_Value
     with Pre => Is_Character (X);
   function To_Object (Ch : Character_Value) return Object
     with Post => Is_Character (To_Object'Result)
     and then To_Character (To_Object'Result) = Ch;

   function Is_Instruction (X : Object) return Boolean;
   function To_Instruction (X : Object) return Raven.Instructions.Instruction
     with Pre => Is_Instruction (X);
   function To_Object
     (Instruction : Raven.Instructions.Instruction)
      return Object
     with Post => Is_Instruction (To_Object'Result)
     and then Raven.Instructions."="
       (To_Instruction (To_Object'Result),
        Instruction);

   --  As many symbols as an extended payload can name.  Generated
   --  symbols are minted one per expansion of a macro that introduces
   --  a name and nothing takes a symbol back, so this is the room to
   --  do that -- and it is not the ceiling that matters, because the
   --  symbol table holds a name per symbol, which runs out of memory
   --  long before it runs out of ids.

   type Symbol_Id is range 1 .. 2 ** Extended_Payload_Bits - 1;

   function Is_Symbol (X : Object) return Boolean;
   function To_Symbol (X : Object) return Symbol_Id
     with Pre => Is_Symbol (X);
   function To_Object (Symbol : Symbol_Id) return Object
     with Post => Is_Symbol (To_Object'Result)
     and then To_Symbol (To_Object'Result) = Symbol;

   --  A closure: the code and the environment it captured, in a cell
   --  of its own kind rather than an ordinary pair.  It was a pair, so
   --  car and cdr took one apart, nothing could tell one from a list,
   --  and a list whose car happened to be a code list could be called.
   --
   --  A closure is an extended type, so its payload is twenty four
   --  bits where a pair's is thirty.  The encoding has three primary
   --  tags and no spare, and a closure is the first thing to have
   --  wanted a fourth; what that costs is the ceiling below, which is
   --  checked where the heap is made.

   Max_Addressable_Cells : constant := 2 ** Extended_Payload_Bits;

   --  A vector: its length and then its elements, packed two to a
   --  cell in the cells after it.  The object names the header, so
   --  everything about it is found by arithmetic rather than by
   --  walking, which is what a vector is for.
   --
   --  The collector walks it without being told how: every element is
   --  an Object and a cell of two of them is what the scan already
   --  reads, and the length is an integer, which it passes over.  What
   --  it does have to be told is how many cells to copy, which is the
   --  length again.

   function Is_Vector (X : Object) return Boolean;
   function To_Vector (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Vector (To_Vector'Result)
     and then Has_Address (To_Vector'Result)
     and then Get_Address (To_Vector'Result) = Address;

   --  A bytevector, which is a vector whose elements may only be a
   --  byte.  It is laid out the way a vector is and held the same
   --  way, one element to a slot, so it is as large as a vector of
   --  the same length rather than a quarter of it.
   --
   --  Packing four to a word is what a bytevector is for and is not
   --  what this does.  The collector reads every cell of a block as
   --  two objects and moves what has an address, so packed bytes
   --  would have to be skipped -- and a cell it must not read is a
   --  cell it must be able to recognise, which this heap has no way
   --  to do.  Nothing about the procedures would change.

   function Is_Bytevector (X : Object) return Boolean;
   function To_Bytevector (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Bytevector (To_Bytevector'Result)
     and then Has_Address (To_Bytevector'Result)
     and then Get_Address (To_Bytevector'Result) = Address;

   --  An exact integer past what a fixnum holds (#102).  It is a block
   --  in the heap laid out as a bytevector is -- a header, and then the
   --  magnitude in packed bytes, least significant first -- with the
   --  sign in the other half of the header.  The collector moves it as
   --  it moves a bytevector, and nothing outside Raven.Numbers reads it.
   --
   --  A bignum is never one that a fixnum could hold: every number an
   --  operation gives back is normal (#100), so a bignum and a fixnum
   --  are never the same number.

   function Is_Bignum (X : Object) return Boolean;
   function To_Bignum (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Bignum (To_Bignum'Result)
     and then Has_Address (To_Bignum'Result)
     and then Get_Address (To_Bignum'Result) = Address;

   function Is_Closure (X : Object) return Boolean;
   function To_Closure (Address : Address_Type) return Object
     with Pre => Address < Max_Addressable_Cells,
     Post => Is_Closure (To_Closure'Result)
     and then Has_Address (To_Closure'Result)
     and then Get_Address (To_Closure'Result) = Address;

   function Has_Address (X : Object) return Boolean;
   function Get_Address (X : Object) return Address_Type
     with Pre => Has_Address (X);

   function Is_Atom (X : Object) return Boolean;
   function Is_Pair (X : Object) return Boolean;

   function To_Pair (Address : Address_Type) return Object
     with Post => Is_Pair (To_Pair'Result)
     and then Has_Address (To_Pair'Result)
     and then Get_Address (To_Pair'Result) = Address;

   --  How many foreign values can be live at once.  An id is given
   --  back when the collector finds nothing naming the value, so this
   --  is not how many a program may make; it is how many it may hold.
   --  Every string is one, and so every port.  The ceiling is what the
   --  payload of an extended object holds, as it is for a symbol.

   type Foreign_Value_Id is range 1 .. 2 ** Extended_Payload_Bits - 1;

   function Is_Foreign_Value (X : Object) return Boolean;
   function To_Foreign_Value_Id (X : Object) return Foreign_Value_Id
     with Pre => Is_Foreign_Value (X);
   function To_Object (Id : Foreign_Value_Id) return Object
     with Post => Is_Foreign_Value (To_Object'Result)
     and then To_Foreign_Value_Id (To_Object'Result) = Id;

   --  As many as the payload of an extended object holds, as a foreign
   --  value's id is.  It was 1 .. 99, which the base library and a
   --  host's own functions between them went past once exceptions
   --  needed four more (#46).

   type Foreign_Function_Id is range 1 .. 2 ** Extended_Payload_Bits - 1;

   function Is_Foreign_Function (X : Object) return Boolean;
   function To_Foreign_Function_Id (X : Object) return Foreign_Function_Id
     with Pre => Is_Foreign_Function (X);
   function To_Object (Id : Foreign_Function_Id) return Object
     with Post => Is_Foreign_Function (To_Object'Result)
     and then To_Foreign_Function_Id (To_Object'Result) = Id;

   --  Packed bytes: an object whose payload is bytes rather than a
   --  value, as many as the payload of an extended object holds.  It is
   --  storage and never a value.  A bytevector's elements are kept in
   --  these, and nothing but the memory's accessors may hold one: they
   --  unpack a byte into an integer on the way out and pack one on the
   --  way in, so no program and no slot ever sees one.
   --
   --  It has no address, so the collector passes it by as it passes an
   --  integer, and every word of the heap is still a whole object.  The
   --  count is derived rather than written, because an object of
   --  another width holds another number of bytes.

   Bytes_Per_Object : constant := Extended_Payload_Bits / 8;

   type Byte is mod 2 ** 8;

   subtype Byte_Position is Natural range 0 .. Bytes_Per_Object - 1;

   function Is_Packed_Bytes (X : Object) return Boolean;

   --  Every byte nought, which is what a new bytevector holds and what
   --  the positions past the end of one are.

   function No_Bytes return Object
     with Post => Is_Packed_Bytes (No_Bytes'Result);

   --  Position nought is the low byte of the payload.

   function Packed_Byte
     (X        : Object;
      Position : Byte_Position)
      return Byte
     with Pre => Is_Packed_Bytes (X);

   function With_Packed_Byte
     (X        : Object;
      Position : Byte_Position;
      Value    : Byte)
      return Object
     with Pre  => Is_Packed_Bytes (X),
          Post => Is_Packed_Bytes (With_Packed_Byte'Result)
                  and then Packed_Byte (With_Packed_Byte'Result, Position)
                             = Value;

   function Image
     (X : Object)
      return String;

   function Tag_Equal (X, Y : Object) return Boolean;

private

   --  The primary tag: two bits, three types and an escape.

   Integer_Tag : constant := 0;
   Float_Tag   : constant := 1;
   Pair_Tag    : constant := 2;
   Escape_Tag  : constant := 3;

   Object_Tag_Mask : constant := 2 ** Object_Tag_Bits - 1;
   Full_Tag_Mask   : constant := 2 ** Full_Tag_Bits - 1;

   function Tag (X : Object) return Object
   is (X and Object_Tag_Mask);

   function Payload (X : Object) return Object
   is (X / 2 ** Object_Tag_Bits);

   function Tag (X        : Object;
                 With_Tag : Object)
                 return Object
   is (X * 2 ** Object_Tag_Bits + With_Tag);

   --  The extended half.  A tag here is the whole eight bits, the
   --  escape included, so that a test on one is the same mask and
   --  compare a primary type takes rather than a decode of two steps.

   Extended_Step : constant := 2 ** Object_Tag_Bits;

   Constant_Tag    : constant := Escape_Tag + 0 * Extended_Step;
   Symbol_Tag      : constant := Escape_Tag + 1 * Extended_Step;
   Character_Tag   : constant := Escape_Tag + 2 * Extended_Step;
   Instruction_Tag : constant := Escape_Tag + 3 * Extended_Step;
   External_Tag    : constant := Escape_Tag + 4 * Extended_Step;
   Foreign_Tag     : constant := Escape_Tag + 5 * Extended_Step;
   Closure_Tag     : constant := Escape_Tag + 6 * Extended_Step;
   Vector_Tag      : constant := Escape_Tag + 7 * Extended_Step;
   Bytevector_Tag  : constant := Escape_Tag + 8 * Extended_Step;
   Bytes_Tag       : constant := Escape_Tag + 9 * Extended_Step;
   Bignum_Tag      : constant := Escape_Tag + 10 * Extended_Step;
   Flonum_Tag      : constant := Escape_Tag + 11 * Extended_Step;
   Ratnum_Tag      : constant := Escape_Tag + 12 * Extended_Step;
   Values_Tag      : constant := Escape_Tag + 13 * Extended_Step;
   Continuation_Tag : constant := Escape_Tag + 14 * Extended_Step;

   function Full_Tag (X : Object) return Object
   is (X and Full_Tag_Mask);

   function Extended_Payload (X : Object) return Object
   is (X / 2 ** Full_Tag_Bits);

   function Extend (X        : Object;
                    With_Tag : Object)
                    return Object
   is (X * 2 ** Full_Tag_Bits + With_Tag);

   --  Two objects are the same kind of thing.  Below the escape that
   --  is the two bit tag; at or above it, it has to be all eight,
   --  because every extended type shares the escape.

   function Tag_Equal (X, Y : Object) return Boolean
   is (if Tag (X) = Escape_Tag
       then Full_Tag (X) = Full_Tag (Y)
       else Tag (X) = Tag (Y));

   Nil_Payload       : constant := 0;
   Undefined_Payload : constant := 1;
   False_Payload     : constant := 2;
   True_Payload      : constant := 3;
   Lambda_Payload    : constant := 4;
   Quote_Payload     : constant := 5;
   Pending_Payload   : constant := 6;
   Cond_Payload      : constant := 7;
   Define_Payload    : constant := 8;
   If_Payload        : constant := 9;
   Eof_Payload       : constant := 10;
   Call_CC_Payload   : constant := 11;

   function Nil return Object
   is (Extend (Nil_Payload, Constant_Tag));

   function Undefined return Object
   is (Extend (Undefined_Payload, Constant_Tag));

   function Pending return Object
   is (Extend (Pending_Payload, Constant_Tag));

   function Eof return Object
   is (Extend (Eof_Payload, Constant_Tag));

   function Is_Eof (X : Object) return Boolean
   is (X = Eof);

   function Lambda return Object
   is (Extend (Lambda_Payload, Constant_Tag));

   function Call_CC return Object
   is (Extend (Call_CC_Payload, Constant_Tag));

   function Cond return Object
   is (Extend (Cond_Payload, Constant_Tag));

   function Define return Object
   is (Extend (Define_Payload, Constant_Tag));

   function If_Obj return Object
   is (Extend (If_Payload, Constant_Tag));

   function Quote return Object
   is (Extend (Quote_Payload, Constant_Tag));

   function To_Object (B : Boolean) return Object
   is (Extend ((if B then True_Payload else False_Payload), Constant_Tag));

   function Is_Truthy (X : Object) return Boolean
   is (Full_Tag (X) /= Constant_Tag or else Extended_Payload (X) > 2);

   --  Integer is 0 and float is 1, so bit one of the tag is clear for
   --  both and set for the pair tag and the escape.

   function Is_Number (X : Object) return Boolean
   is ((X and 2#10#) = 0
       or else Full_Tag (X) = Bignum_Tag
       or else Full_Tag (X) = Flonum_Tag
       or else Full_Tag (X) = Ratnum_Tag);

   function Is_Integer (X : Object) return Boolean
   is (Tag (X) = Integer_Tag);

   function To_Integer (X : Object) return Integer
   is (declare P : constant Object := Payload (X);
       begin (if P > Max_Integer
         then Integer (P) - 2 ** Object_Payload_Bits
         else Integer (P)));

   function To_Object (I : Integer) return Object
   is (if I >= 0
       then Tag (Object (I), Integer_Tag)
       else Tag (Object (2 ** Object_Payload_Bits + I), Integer_Tag));

   function Is_Float (X : Object) return Boolean
   is (Tag (X) = Float_Tag);

   function Is_Character (X : Object) return Boolean
   is (Full_Tag (X) = Character_Tag);

   function To_Character (X : Object) return Character_Value
   is (Wide_Wide_Character'Val (Extended_Payload (X)));

   function To_Object (Ch : Character_Value) return Object
   is (Extend (Wide_Wide_Character'Pos (Ch), Character_Tag));

   function Is_Instruction (X : Object) return Boolean
   is (Full_Tag (X) = Instruction_Tag);

   function To_Instruction (X : Object) return Raven.Instructions.Instruction
   is (Raven.Instructions.Instruction'Val (Extended_Payload (X)));

   function To_Object
     (Instruction : Raven.Instructions.Instruction)
      return Object
   is (Extend (Object (Raven.Instructions.Instruction'Pos (Instruction)),
       Instruction_Tag));

   function Is_Symbol (X : Object) return Boolean
   is (Full_Tag (X) = Symbol_Tag);

   function To_Symbol (X : Object) return Symbol_Id
   is (Symbol_Id (Extended_Payload (X)));

   function To_Object (Symbol : Symbol_Id) return Object
   is (Extend (Object (Symbol), Symbol_Tag));

   --  Both of the things that name a cell, which is what the
   --  collector asks about: it has to walk a closure's code and
   --  environment exactly as it walks a pair's car and cdr.

   function Has_Address (X : Object) return Boolean
   is (Tag (X) = Pair_Tag
       or else Full_Tag (X) = Closure_Tag
       or else Full_Tag (X) = Vector_Tag
       or else Full_Tag (X) = Bytevector_Tag
       or else Full_Tag (X) = Bignum_Tag
       or else Full_Tag (X) = Flonum_Tag
       or else Full_Tag (X) = Ratnum_Tag
       or else Full_Tag (X) = Values_Tag
       or else Full_Tag (X) = Continuation_Tag);

   --  And their payloads are not in the same place, because one of
   --  them is an extended type.

   function Get_Address (X : Object) return Address_Type
   is (if Tag (X) = Pair_Tag
       then Address_Type (Payload (X))
       else Address_Type (Extended_Payload (X)));

   function Is_Closure (X : Object) return Boolean
   is (Full_Tag (X) = Closure_Tag);

   function To_Closure (Address : Address_Type) return Object
   is (Extend (Object (Address), Closure_Tag));

   function Is_Vector (X : Object) return Boolean
   is (Full_Tag (X) = Vector_Tag);

   function To_Vector (Address : Address_Type) return Object
   is (Extend (Object (Address), Vector_Tag));

   function Is_Bytevector (X : Object) return Boolean
   is (Full_Tag (X) = Bytevector_Tag);

   function Is_Packed_Bytes (X : Object) return Boolean
   is (Full_Tag (X) = Bytes_Tag);

   function Is_Bignum (X : Object) return Boolean
   is (Full_Tag (X) = Bignum_Tag);

   function Is_Flonum (X : Object) return Boolean
   is (Full_Tag (X) = Flonum_Tag);

   function Is_Ratnum (X : Object) return Boolean
   is (Full_Tag (X) = Ratnum_Tag);

   function Is_Values (X : Object) return Boolean
   is (Full_Tag (X) = Values_Tag);

   function Is_Continuation (X : Object) return Boolean
   is (Full_Tag (X) = Continuation_Tag);

   function To_Continuation (Address : Address_Type) return Object
   is (Extend (Object (Address), Continuation_Tag));

   function To_Values (Address : Address_Type) return Object
   is (Extend (Object (Address), Values_Tag));

   function To_Ratnum (Address : Address_Type) return Object
   is (Extend (Object (Address), Ratnum_Tag));

   function To_Flonum (Address : Address_Type) return Object
   is (Extend (Object (Address), Flonum_Tag));

   function To_Bignum (Address : Address_Type) return Object
   is (Extend (Object (Address), Bignum_Tag));

   function No_Bytes return Object
   is (Extend (0, Bytes_Tag));

   function Packed_Byte
     (X        : Object;
      Position : Byte_Position)
      return Byte
   is (Byte ((Extended_Payload (X) / 2 ** (8 * Position)) mod 2 ** 8));

   function With_Packed_Byte
     (X        : Object;
      Position : Byte_Position;
      Value    : Byte)
      return Object
   is (Extend
         (Extended_Payload (X)
          - Object (Packed_Byte (X, Position)) * 2 ** (8 * Position)
          + Object (Value) * 2 ** (8 * Position),
          Bytes_Tag));

   function To_Bytevector (Address : Address_Type) return Object
   is (Extend (Object (Address), Bytevector_Tag));

   function Is_Pair (X : Object) return Boolean
   is (Tag (X) = Pair_Tag);

   function Is_Atom (X : Object) return Boolean
   is (not Is_Pair (X));

   function To_Pair (Address : Address_Type) return Object
   is (Tag (Object (Address), Pair_Tag));

   function Is_Foreign_Value (X : Object) return Boolean
   is (Full_Tag (X) = External_Tag);

   function To_Foreign_Value_Id (X : Object) return Foreign_Value_Id
   is (Foreign_Value_Id (Extended_Payload (X)));

   function To_Object (Id : Foreign_Value_Id) return Object
   is (Extend (Object (Id), External_Tag));

   function Is_Foreign_Function (X : Object) return Boolean
   is (Full_Tag (X) = Foreign_Tag);

   function To_Foreign_Function_Id (X : Object) return Foreign_Function_Id
   is (Foreign_Function_Id (Extended_Payload (X)));

   function To_Object (Id : Foreign_Function_Id) return Object
   is (Extend (Object (Id), Foreign_Tag));

end Raven.Objects;
