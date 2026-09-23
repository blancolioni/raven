with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Raven.Engine;
with Raven.Evaluator;
with Raven.IO;
with Raven.Loader;
with Raven.Memory;
with Raven.Objects;
with Raven.Parser;
with Raven.Strings;
with Raven.Target;
with Raven_Config;
with Resources;

package body Raven is

   function Decode (S : String) return Wide_Wide_String
   is (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (S));

   function Encode (T : Wide_Wide_String) return String
   is (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (T));

   package Raven_Resources is
     new Resources (Raven_Config.Crate_Name);

   type Raven_VM_Record is
      record
         Text_Writer : Write_Text_Handler;
         File_Reader : Read_File_Handler;
         User_Data   : User_Data_Reference;
         Evaluator   : Raven.Evaluator.Reference;
         Memory      : Raven.Memory.Reference;
         Target      : Raven.Target.Reference;
         IO          : Raven.IO.Reference;
      end record;

   procedure Write_Character
     (This : Raven_VM);

   ----------------------
   -- Add_Library_Path --
   ----------------------

   procedure Add_Library_Path
     (This : Raven_VM;
      Path : String)
   is
   begin
      This.Data.Target.Add_Library_Path (Path);
   end Add_Library_Path;

   ---------------
   -- Bind_Name --
   ---------------

   function Bind_Name
     (This : Raven_VM;
      Name : String)
      return Handle
   is
   begin
      return (Position => This.Data.Evaluator.Bind_Handle_To_Name (Name));
   end Bind_Name;

   ---------------------------
   -- Bind_Foreign_Function --
   ---------------------------

   procedure Bind_Foreign_Function
     (This           : Raven_VM;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural)
   is
   begin
      This.Data.Evaluator.Bind_Foreign_Function
        (Name, Handler, Argument_Count);
   end Bind_Foreign_Function;

   ---------
   -- Car --
   ---------

   function Car (This : Raven_VM'Class;
                 Pair : Object)
                 return Object
   is
   begin
      return This.Data.Memory.Get (Objects.Get_Address (Pair)).Car;
   end Car;

   ---------
   -- Cdr --
   ---------

   function Cdr (This : Raven_VM'Class;
                 Pair : Object)
                 return Object
   is
   begin
      return This.Data.Memory.Get (Objects.Get_Address (Pair)).Cdr;
   end Cdr;

   ------------------
   -- Close_Handle --
   ------------------

   procedure Close_VM (This : in out Raven_VM) is
   begin
      null;
   end Close_VM;

   --------------------------
   -- Create_Foreign_Value --
   --------------------------

   function Create_Foreign_Value
     (This  : Raven_VM'Class;
      Value : Foreign_Value_Instance'Class)
      return Object
   is
   begin
      return This.Data.Memory.Create_Foreign_Value (Value);
   end Create_Foreign_Value;

   -------------
   -- Display --
   -------------

   function Display
     (This : Raven_VM'Class;
      Value : Object)
      return Wide_Wide_String
   is
      Image : constant String := This.Data.Target.Show (Value);
   begin
      return Decode (Image);
   end Display;

   -----------
   -- Equal --
   -----------

   function Equal
     (This : Raven_VM'Class;
      X, Y : Object)
      return Boolean
   is
      use Raven.Objects;
      B : Boolean := False;
   begin
      if X = Y then
         B := True;
      elsif not Tag_Equal (X, Y) then
         B := False;
      elsif Is_Foreign_Value (X) then
         B := This.To_Foreign_Value (X).Equal
           (This.To_Foreign_Value (Y));
      elsif Is_Foreign_Function (X) then
         B := False;
      elsif Is_Pair (X) then
         B := This.Equal (This.Car (X), This.Car (Y))
           and then This.Equal (This.Cdr (X), This.Cdr (Y));
      elsif Is_Atom (X) then
         B := False;
      else
         B := False;
      end if;
      return B;
   end Equal;

   --------------
   -- Evaluate --
   --------------

   procedure Evaluate
     (This       : Raven_VM;
      Expression : String)
   is
   begin
      Raven.Parser.Parse_Expression
        (Expression, This.Data.Target);

      This.Data.Target.Translate
        (This.Data.Target.Interaction_Library);
      This.Data.Target.Execute;

      This.Set_Slot (1, This.Data.Target.Pop);

   end Evaluate;

   --------------
   -- Evaluate --
   --------------

   procedure Evaluate
     (This  : Raven_VM;
      Value : Handle)
   is
      Fn : constant Object := Object_Lists.Element (Value.Position);
   begin
      This.Data.Target.Push (Fn);
      This.Data.Target.Translate
        (This.Data.Target.Interaction_Library);
      This.Data.Target.Execute;
      This.Set_Slot (1, This.Data.Target.Pop);
   end Evaluate;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index)
      return Object
   is
   begin
      return This.Data.Evaluator.Get_Slot (Index);
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Boolean
   is
   begin
      return Raven.Objects.Is_Truthy (This.Get_Slot (Index));
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Integer
   is
   begin
      return Raven.Objects.To_Integer (This.Get_Slot (Index));
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return String
   is
   begin
      if Raven.Strings.Is_String (This, Index) then
         return Raven.Strings.Get_String (This, Index);
      else
         return This.Data.Target.Show (This.Get_Slot (Index));
      end if;
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Handle
   is
   begin
      return Handle'(Position => Object_Lists.No_Element);
   end Get_Slot;

   --------------------
   -- Import_Library --
   --------------------

   procedure Import_Library
     (This : Raven_VM'Class;
      Name : String;
      Path : String)
   is
   begin
      Raven.Loader.Import (This.Data.Target, Name, Path);
   end Import_Library;

   ----------------
   -- New_Symbol --
   ----------------

   function New_Symbol
     (This   : Raven_VM'Class;
      Prefix : String)
      return Object
   is
   begin
      return This.Data.Target.New_Symbol (Prefix);
   end New_Symbol;

   -------------
   -- New_VM  --
   -------------

   function New_VM
     (Text_Writer   : Write_Text_Handler := null;
      File_Reader   : Read_File_Handler  := null;
      User_Data     : access User_Data_Interface'Class := null;
      Configuration : String := "")
      return Raven_VM
   is
      Memory : constant Raven.Memory.Reference :=
                 Raven.Engine.Create_Memory (65536);

      This : constant Raven_VM :=
               (Data => new Raven_VM_Record'
                  (Text_Writer => Text_Writer,
                   File_Reader => File_Reader,
                   User_Data   => User_Data,
                   IO          => Raven.IO.Standard_IO,
                   Memory      => Memory,
                   Evaluator   => null,
                   Target      => null));
   begin
      This.Data.Evaluator := Raven.Engine.Create (This, Memory, Configuration);
      This.Bind_Foreign_Function
        ("raven-write-char", Write_Character'Access, 1);
      This.Data.Target    := This.Data.Evaluator.Target;

      This.Add_Library_Path (Standard_Library_Path);

      Raven.Loader.Import
        (This.Data.Target, "(scheme base)",
         Standard_Library_Path & "/scheme/base.scm");
      return This;
   end New_VM;

   ------------------
   -- Report_State --
   ------------------

   procedure Report_State (This : Raven_VM) is
   begin
      This.Data.Evaluator.Report;
   end Report_State;

   ---------------
   -- Slot_Cons --
   ---------------

   procedure Slot_Cons
     (This     : Raven_VM;
      Index    : Slot_Index;
      Car_Slot : Slot_Index)
   is
   begin
      This.Data.Evaluator.Set_Slot
        (Index,
         This.Data.Evaluator.Cons
           (This.Data.Evaluator.Get_Slot (Car_Slot),
            This.Data.Evaluator.Get_Slot (Index)));
   end Slot_Cons;

   -------------------
   -- Set_Parameter --
   -------------------

   procedure Set_Parameter
     (This  : Raven_VM;
      Name  : String;
      Value : String)
   is
   begin
      This.Data.Target.Set_Parameter (Name, Value);
   end Set_Parameter;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index;
      Value : Object)
   is
   begin
      This.Data.Evaluator.Set_Slot (Index, Value);
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Boolean)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.To_Object (Value));
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Integer)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.To_Object (Value));
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : String)
   is
   begin
      This.Set_Slot
        (Index,
         Raven.Objects.To_Object
           (This.Data.Target.To_Symbol_Id (Value)));
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Handle)
   is
   begin
      This.Set_Slot (Index, Object_Lists.Element (Value.Position));
   end Set_Slot;

   ------------------
   -- Set_Slot_Nil --
   ------------------

   procedure Set_Slot_Nil
     (This  : Raven_VM;
      Index : Slot_Index)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.Nil);
   end Set_Slot_Nil;

   ---------------------------
   -- Standard_Library_Path --
   ---------------------------

   function Standard_Library_Path return string is
   begin
      return Raven_Resources.Resource_Path & "/libraries";
   end Standard_Library_Path;

   ----------------------
   -- To_Foreign_Value --
   ----------------------

   function To_Foreign_Value
     (This : Raven_VM'Class;
      Value : Object)
      return Foreign_Value_Instance'Class
   is
   begin
      return This.Data.Memory.To_Foreign_Value (Value);
   end To_Foreign_Value;

   ---------------
   -- User_Data --
   ---------------

   function User_Data
     (This : Raven_VM)
      return User_Data_Reference
   is
   begin
      return This.Data.User_Data;
   end User_Data;

   ---------------------
   -- Write_Character --
   ---------------------

   procedure Write_Character
     (This : Raven_VM)
   is
      X    : constant Object := This.Get_Slot (1);
      Ch   : constant Wide_Wide_Character :=
               Raven.Objects.To_Character (X);
   begin
      This.Data.IO.Put (Ch);
   end Write_Character;

end Raven;
