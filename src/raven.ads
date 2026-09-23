private with Ada.Containers.Doubly_Linked_Lists;

package Raven is

   Version_Major   : constant Natural := 0;
   Version_Minor   : constant Natural := 1;
   Version_Release : constant Natural := 0;
   Version_Name    : constant String := "raven";
   Version_String  : constant String := "raven-0.1.0";

   type User_Data_Interface is interface;
   type User_Data_Reference is access all User_Data_Interface'Class;

   type Raven_VM is tagged private;

   type Write_Text_Handler is access
     procedure (VM      : Raven_VM;
                Message : String);

   type Read_File_Handler is access
     function (VM        : Raven_VM;
               File_Name : String) return String;

   --  Library_Path is where the scheme library this VM is built with
   --  is read from, and the first place (import ...) looks.  Empty is
   --  the one installed beside the executable, which is what a program
   --  that ships with raven wants; a host that keeps the library
   --  somewhere of its own says where.

   function New_VM
     (Text_Writer   : Write_Text_Handler := null;
      File_Reader   : Read_File_Handler  := null;
      User_Data     : access User_Data_Interface'Class := null;
      Configuration : String := "";
      Library_Path  : String := "")
      return Raven_VM;

   procedure Close_VM (This : in out Raven_VM);

   function User_Data
     (This : Raven_VM)
      return User_Data_Reference;

   type Handle is private;

   function Is_Null (This : Handle) return Boolean;

   function Bind_Name
     (This : Raven_VM;
      Name : String)
      return Handle;

   type Slot_Index is range 1 .. 16;

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Boolean;

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Integer;

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return String;

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Handle;

   procedure Set_Slot_Nil
     (This  : Raven_VM;
      Index : Slot_Index);

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Boolean);

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Integer);

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : String);

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Handle);

   procedure Slot_Cons
     (This     : Raven_VM;
      Index    : Slot_Index;
      Car_Slot : Slot_Index);

   procedure Evaluate
     (This       : Raven_VM;
      Expression : String);

   procedure Evaluate
     (This  : Raven_VM;
      Value : Handle);

   type Foreign_Value_Instance is abstract tagged private;

   function Show (This : Foreign_Value_Instance) return String is abstract;
   procedure Mark (This : in out Foreign_Value_Instance) is null;
   procedure Free (This : in out Foreign_Value_Instance) is null;
   function Equal (This : Foreign_Value_Instance;
                   To   : Foreign_Value_Instance)
                   return Boolean
                   is abstract;

   type Foreign_Function_Handler is access
     procedure (VM : Raven_VM);

   procedure Bind_Foreign_Function
     (This           : Raven_VM;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural);

   procedure Set_Parameter
     (This  : Raven_VM;
      Name  : String;
      Value : String);

   --  Where (import (scheme base)) looks for a library: the directory
   --  a name is taken as a path below.  The standard library's own
   --  directory is on the path already.

   procedure Add_Library_Path
     (This : Raven_VM;
      Path : String);

   procedure Report_State (This : Raven_VM);

private

   Object_Size         : constant := 32;
   Object_Tag_Bits     : constant := 4;
   Object_Payload_Bits : constant := Object_Size - Object_Tag_Bits;

   type Object is mod 2 ** Object_Size;

   type Address_Type is mod 2 ** (Object_Size - Object_Tag_Bits);

   package Object_Lists is
     new Ada.Containers.Doubly_Linked_Lists (Object);

   type Object_Array is array (Positive range <>) of Object;

   type Handle is
      record
         Position : Object_Lists.Cursor := Object_Lists.No_Element;
      end record;

   function Is_Null (This : Handle) return Boolean
   is (not Object_Lists.Has_Element (This.Position));

   type Raven_VM_Record;

   type Raven_VM_Access is access Raven_VM_Record;

   type Raven_VM is tagged
      record
         Data : Raven_VM_Access;
      end record;

   function Get_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index)
      return Object;

   procedure Set_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index;
      Value : Object);

   function New_Symbol
     (This   : Raven_VM'Class;
      Prefix : String)
      return Object;

   function Car (This : Raven_VM'Class;
                 Pair : Object)
                 return Object;

   function Cdr (This : Raven_VM'Class;
                 Pair : Object)
                 return Object;

   --  Writing a cell, which is what the machine has always done for
   --  RAP and for set! on an argument.  Nothing is asked of what is
   --  replaced.

   procedure Set_Car (This  : Raven_VM'Class;
                      Pair  : Object;
                      Value : Object);

   procedure Set_Cdr (This  : Raven_VM'Class;
                      Pair  : Object;
                      Value : Object);

   --  The symbol this name reads as.  Not New_Symbol, which mints one
   --  that no name reads as: two calls of this with the same name give
   --  the same symbol, which is the whole of what string->symbol
   --  promises.

   function To_Symbol
     (This : Raven_VM'Class;
      Name : String)
      return Object;

   type Foreign_Value_Instance is abstract tagged
      record
         Marked : Boolean := False;
      end record;

   function Create_Foreign_Value
     (This  : Raven_VM'Class;
      Value : Foreign_Value_Instance'Class)
      return Object;

   function To_Foreign_Value
     (This  : Raven_VM'Class;
      Value : Object)
      return Foreign_Value_Instance'Class;

   function Display
     (This : Raven_VM'Class;
      Value : Object)
      return Wide_Wide_String;

   function Equal
     (This : Raven_VM'Class;
      X, Y : Object)
      return Boolean;

   function Standard_Library_Path return String;

   --  Load a scheme source file as a library of this name, and import
   --  it into the library the host's own forms are translated in.  The
   --  file is read whether or not a library of the name is loaded, so
   --  this is also how a library is loaded again over itself.  New_VM
   --  imports the standard library itself; this is for libraries that
   --  are not part of it, such as the scheme test suite, which belongs
   --  to the test harness rather than to every VM.

   procedure Import_Library
     (This : Raven_VM'Class;
      Name : String;
      Path : String);

   function Encode (T : Wide_Wide_String) return String;
   function Decode (S : String) return Wide_Wide_String;

end Raven;
