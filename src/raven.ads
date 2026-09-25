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

   --  How many cells a VM's heap has.  The collector copies what is
   --  live into the other half of it, so a program has half of these
   --  to itself: the default gives it 32,768, which is 512 KB of heap
   --  all told at eight bytes a cell.
   --
   --  It wants to be said rather than assumed.  A host with less
   --  memory than that cannot have raven at all otherwise, and one
   --  with a great deal more cannot ask for it.  The standard library
   --  is about 6,500 live cells once it is loaded, which is the floor
   --  under anything useful.

   Default_Heap_Size : constant := 65_536;

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
      Library_Path  : String := "";
      Heap_Size     : Positive := Default_Heap_Size)
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

   --  What a foreign value looks like written so that it can be read
   --  back, and what it looks like for a person to read.  They are the
   --  same thing unless the kind of value has quotation marks or
   --  escapes that are only there for the reader, which is why Display
   --  has an answer of its own to give and Show does not.

   function Show (This : Foreign_Value_Instance) return String is abstract;
   function Display (This : Foreign_Value_Instance) return String;
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

   --  An object is a tagged word, and the tag is two bits: three types
   --  and an escape.  The three are the ones that want a payload wider
   --  than the escape leaves -- an integer, which is the range; a
   --  float, which is an immediate and needs every bit there is; and a
   --  pair, whose payload is the ceiling on the heap.  Everything else
   --  is reached through the escape, with six more bits of tag above
   --  it and twenty four of payload below.
   --
   --  Asking about an extended type costs what asking about a primary
   --  one costs, because the whole eight bit pattern is a constant: a
   --  mask and a compare either way, and one shift to get the payload
   --  out.  So what a primary slot buys is width and not speed, which
   --  is why the three that have one are the three that need it.

   Object_Size           : constant := 32;
   Object_Tag_Bits       : constant := 2;
   Object_Payload_Bits   : constant := Object_Size - Object_Tag_Bits;

   Extended_Tag_Bits     : constant := 6;
   Full_Tag_Bits         : constant := Object_Tag_Bits + Extended_Tag_Bits;
   Extended_Payload_Bits : constant := Object_Size - Full_Tag_Bits;

   type Object is mod 2 ** Object_Size;

   --  A pair is a primary type, so an address is as wide as a payload
   --  and the heap's ceiling is not the encoding's business.

   type Address_Type is mod 2 ** Object_Payload_Bits;

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

   --  A vector of this many elements, every one of them nil, and the
   --  three things that can be asked of one.  Making one may collect,
   --  so whatever is to go in it belongs in a slot until it is made.

   function New_Vector
     (This   : Raven_VM'Class;
      Length : Natural)
      return Object;

   --  What the host reads, a character at a time, and whether there
   --  was one.  Nothing could read at all before ports.

   procedure Read_Character
     (This      : Raven_VM'Class;
      Ch        : out Wide_Wide_Character;
      Available : out Boolean);

   procedure Write_Character
     (This   : Raven_VM'Class;
      Ch     : Wide_Wide_Character;
      Errors : Boolean);

   function New_Bytevector
     (This   : Raven_VM'Class;
      Length : Natural)
      return Object;

   function Vector_Length
     (This : Raven_VM'Class;
      V    : Object)
      return Natural;

   function Vector_Element
     (This  : Raven_VM'Class;
      V     : Object;
      Index : Natural)
      return Object;

   procedure Set_Vector_Element
     (This  : Raven_VM'Class;
      V     : Object;
      Index : Natural;
      Value : Object);

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

   --  Readable says which of the two is wanted: what the reader could
   --  read back, or what a person reads.  It is the first by default,
   --  because every caller but display wants a thing it can quote in a
   --  message about what went wrong.

   function Display
     (This     : Raven_VM'Class;
      Value    : Object;
      Readable : Boolean := True)
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
