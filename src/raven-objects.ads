with Raven.Instructions;

private package Raven.Objects is

   function Nil return Object
     with Post => not Is_Truthy (Nil'Result);

   function Undefined return Object
     with Post => not Is_Truthy (Undefined'Result);

   function Pending return Object;

   function Lambda return Object;
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

   function Is_Integer (X : Object) return Boolean;
   function To_Integer (X : Object) return Integer
     with Pre => Is_Integer (X);
   function To_Object (I : Integer) return Object
     with Post => Is_Integer (To_Object'Result)
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
   --  Every string is one.

   type Foreign_Value_Id is range 1 .. 9_999;

   function Is_Foreign_Value (X : Object) return Boolean;
   function To_Foreign_Value_Id (X : Object) return Foreign_Value_Id
     with Pre => Is_Foreign_Value (X);
   function To_Object (Id : Foreign_Value_Id) return Object
     with Post => Is_Foreign_Value (To_Object'Result)
     and then To_Foreign_Value_Id (To_Object'Result) = Id;

   type Foreign_Function_Id is range 1 .. 99;

   function Is_Foreign_Function (X : Object) return Boolean;
   function To_Foreign_Function_Id (X : Object) return Foreign_Function_Id
     with Pre => Is_Foreign_Function (X);
   function To_Object (Id : Foreign_Function_Id) return Object
     with Post => Is_Foreign_Function (To_Object'Result)
     and then To_Foreign_Function_Id (To_Object'Result) = Id;

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

   Max_Integer : constant := 2 ** (Object_Payload_Bits - 1) - 1;
   Min_Integer : constant := -2 ** (Object_Payload_Bits - 1);

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

   function Nil return Object
   is (Extend (Nil_Payload, Constant_Tag));

   function Undefined return Object
   is (Extend (Undefined_Payload, Constant_Tag));

   function Pending return Object
   is (Extend (Pending_Payload, Constant_Tag));

   function Lambda return Object
   is (Extend (Lambda_Payload, Constant_Tag));

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
   is ((X and 2#10#) = 0);

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
   is (Tag (X) = Pair_Tag or else Full_Tag (X) = Closure_Tag);

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
