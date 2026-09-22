private with Ada.Unchecked_Conversion;
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

   function Is_Integer (X : Object) return Boolean;
   function To_Integer (X : Object) return Integer
     with Pre => Is_Integer (X);
   function To_Object (I : Integer) return Object
     with Post => Is_Integer (To_Object'Result)
     and then To_Integer (To_Object'Result) = I;

   function Is_Float (X : Object) return Boolean;
   function To_Float (X : Object) return Float
     with Pre => Is_Float (X);
   function To_Object (F : Float) return Object
     with Post => Is_Float (To_Object'Result)
     and then To_Float (To_Object'Result) = F;

   function Is_Character (X : Object) return Boolean;
   function To_Character (X : Object) return Wide_Wide_Character
     with Pre => Is_Character (X);
   function To_Object (Ch : Wide_Wide_Character) return Object
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

   --  As many symbols as an object can name.  Generated symbols are
   --  minted one per expansion of a macro that introduces a name, and
   --  nothing takes a symbol back, so the room to do that is the whole
   --  of what the payload can hold.

   type Symbol_Id is range 1 .. 2 ** Object_Payload_Bits - 1;

   function Is_Symbol (X : Object) return Boolean;
   function To_Symbol (X : Object) return Symbol_Id
     with Pre => Is_Symbol (X);
   function To_Object (Symbol : Symbol_Id) return Object
     with Post => Is_Symbol (To_Object'Result)
     and then To_Symbol (To_Object'Result) = Symbol;

   function Has_Address (X : Object) return Boolean;
   function Get_Address (X : Object) return Address_Type
     with Pre => Has_Address (X);

   function Is_Atom (X : Object) return Boolean;
   function Is_Pair (X : Object) return Boolean;

   function To_Pair (Address : Address_Type) return Object
     with Post => Is_Pair (To_Pair'Result)
     and then Has_Address (To_Pair'Result)
     and then Get_Address (To_Pair'Result) = Address;

   type Foreign_Value_Id is range 1 .. 99;

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

   Object_Tag_Mask : constant := 2 ** Object_Tag_Bits - 1;

   Max_Integer : constant := 2 ** (Object_Payload_Bits - 1) - 1;
   Min_Integer : constant := -2 ** (Object_Payload_Bits - 1);

   function Tag (X : Object) return Object
   is (X and Object_Tag_Mask);

   function Payload (X : Object) return Object
   is (X / 2 ** Object_Tag_Bits);

   function Tag_Equal (X, Y : Object) return Boolean
   is (Tag (X) = Tag (Y));

   function Tag (X        : Object;
                 With_Tag : Object)
                 return Object
   is (X * 2 ** Object_Tag_Bits + With_Tag);

   Constant_Tag    : constant := 0;
   Integer_Tag     : constant := 1;
   Symbol_Tag      : constant := 2;
   Pair_Tag        : constant := 3;
   Character_Tag   : constant := 4;
   Float_Tag       : constant := 5;
   External_Tag    : constant := 6;
   Foreign_Tag     : constant := 7;
   Instruction_Tag : constant := 8;

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
   is (Tag (Nil_Payload, Constant_Tag));

   function Undefined return Object
   is (Tag (Undefined_Payload, Constant_Tag));

   function Pending return Object
   is (Tag (Pending_Payload, Constant_Tag));

   function Lambda return Object
   is (Tag (Lambda_Payload, Constant_Tag));

   function Cond return Object
   is (Tag (Cond_Payload, Constant_Tag));

   function Define return Object
   is (Tag (Define_Payload, Constant_Tag));

   function If_Obj return Object
   is (Tag (If_Payload, Constant_Tag));

   function Quote return Object
   is (Tag (Quote_Payload, Constant_Tag));

   function To_Object (B : Boolean) return Object
   is (Tag ((if B then True_Payload else False_Payload), Constant_Tag));

   function Is_Truthy (X : Object) return Boolean
   is (Tag (X) /= Constant_Tag or else Payload (X) > 2);

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

   function Payload_To_Float is
     new Ada.Unchecked_Conversion (Object, Float);
   function Float_To_Payload is
     new Ada.Unchecked_Conversion (Float, Object);

   function Is_Float (X : Object) return Boolean
   is (Tag (X) = Float_Tag);

   function To_Float (X : Object) return Float
   is (Payload_To_Float (X and not Object_Tag_Mask));

   function To_Object (F : Float) return Object
   is ((Float_To_Payload (F) and not Object_Tag_Mask) or Float_Tag);

   function Is_Character (X : Object) return Boolean
   is (Tag (X) = Character_Tag);

   function To_Character (X : Object) return Wide_Wide_Character
   is (Wide_Wide_Character'Val (Payload (X)));

   function To_Object (Ch : Wide_Wide_Character) return Object
   is (Tag (Wide_Wide_Character'Pos (Ch), Character_Tag));

   function Is_Instruction (X : Object) return Boolean
   is (Tag (X) = Instruction_Tag);

   function To_Instruction (X : Object) return Raven.Instructions.Instruction
   is (Raven.Instructions.Instruction'Val (Payload (X)));

   function To_Object
     (Instruction : Raven.Instructions.Instruction)
      return Object
   is (Tag (Object (Raven.Instructions.Instruction'Pos (Instruction)),
       Instruction_Tag));

   function Is_Symbol (X : Object) return Boolean
   is (Tag (X) = Symbol_Tag);

   function To_Symbol (X : Object) return Symbol_Id
   is (Symbol_Id (Payload (X)));

   function To_Object (Symbol : Symbol_Id) return Object
   is (Tag (Object (Symbol), Symbol_Tag));

   function Has_Address (X : Object) return Boolean
   is (Tag (X) = Pair_Tag);

   function Get_Address (X : Object) return Address_Type
   is (Address_Type (Payload (X)));

   function Is_Pair (X : Object) return Boolean
   is (Tag (X) = Pair_Tag);

   function Is_Atom (X : Object) return Boolean
   is (not Is_Pair (X));

   function To_Pair (Address : Address_Type) return Object
   is (Tag (Object (Address), Pair_Tag));

   function Is_Foreign_Value (X : Object) return Boolean
   is (Tag (X) = External_Tag);

   function To_Foreign_Value_Id (X : Object) return Foreign_Value_Id
   is (Foreign_Value_Id (Payload (X)));

   function To_Object (Id : Foreign_Value_Id) return Object
   is (Tag (Object (Id), External_Tag));

   function Is_Foreign_Function (X : Object) return Boolean
   is (Tag (X) = Foreign_Tag);

   function To_Foreign_Function_Id (X : Object) return Foreign_Function_Id
   is (Foreign_Function_Id (Payload (X)));

   function To_Object (Id : Foreign_Function_Id) return Object
   is (Tag (Object (Id), Foreign_Tag));

end Raven.Objects;
