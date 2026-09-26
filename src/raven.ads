private with Ada.Containers.Doubly_Linked_Lists;

package Raven is

   Version_Major   : constant Natural := 0;
   Version_Minor   : constant Natural := 1;
   Version_Release : constant Natural := 0;
   Version_Name    : constant String := "raven";
   Version_String  : constant String := "raven-0.1.0";

   type User_Data_Interface is interface;
   type User_Data_Reference is access all User_Data_Interface'Class;

   --  A value of the machine's, held without being looked into.  What
   --  it is made of is the encoding's business and is private, but a
   --  host has to be able to keep one: a foreign value that stands
   --  for something of the host's and refers to something of the
   --  program's has nowhere else to put it.
   --
   --  Keeping one is not free.  The collector moves what it copies,
   --  so a value kept anywhere the collector does not walk is wrong
   --  after the next collection.  Foreign_Value_Instance.Mark is how
   --  a foreign value hands over what it keeps.

   type Object is private;

   --  Where a VM writes, where it writes what went wrong, and where
   --  it reads.  A host that embeds raven gives New_VM one of these
   --  to say where each of the three goes; a VM without one uses the
   --  terminal it was started from.
   --
   --  Every operation is abstract rather than a default that does
   --  nothing, because a host that forgets one should be told so
   --  where it is compiled and not by output quietly going nowhere.
   --  Write_Text_Handler and Read_File_Handler, which New_VM took and
   --  nothing ever called, are what this replaces.
   --
   --  Files are not here.  Everything a VM reads today is either the
   --  library it ships with, found on a path the host sets, or a path
   --  the host itself handed to Import_Library, so there is nothing a
   --  program can read that the host did not already choose.  File
   --  ports are what change that, and are where this grows a way to
   --  say no.

   type IO_Interface is interface;
   type IO_Reference is access all IO_Interface'Class;

   procedure Put
     (This : in out IO_Interface;
      Ch   : Wide_Wide_Character)
   is abstract;

   procedure Put_Error
     (This : in out IO_Interface;
      Ch   : Wide_Wide_Character)
   is abstract;

   --  Available says whether there was a character to be had.  A host
   --  that has none says so rather than waiting: read-char answers
   --  with the end of the port, so a program is never held up by one
   --  of these, and char-ready? is true whichever way it goes.

   procedure Get
     (This      : in out IO_Interface;
      Ch        : out Wide_Wide_Character;
      Available : out Boolean)
   is abstract;

   type Raven_VM is tagged private;

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

   --  IO is the host of this VM: where it writes, where it writes
   --  what went wrong, and where it reads.  Null is the terminal.

   function New_VM
     (IO            : IO_Reference := null;
      User_Data     : access User_Data_Interface'Class := null;
      Configuration : String := "";
      Library_Path  : String := "";
      Heap_Size     : Positive := Default_Heap_Size)
      return Raven_VM;

   procedure Close_VM (This : in out Raven_VM);

   function User_Data
     (This : Raven_VM)
      return User_Data_Reference;

   --  How many forms this VM has abandoned: read, and then given up
   --  on part way through, because the form named something undefined
   --  or the translator refused it.  One bad form does not stop a
   --  file, which is right, but nothing downstream could tell it had
   --  happened -- a suite whose tests never ran looked exactly like
   --  one where every test passed.
   --
   --  It only ever goes up, so a caller that wants to know whether
   --  some particular thing was read whole reads this before and
   --  after and compares.

   function Forms_Abandoned (This : Raven_VM) return Natural;

   --  A whole line of complaint, where this VM's host said errors go.
   --  The loader, the translator and the lexer all wrote to the
   --  terminal directly, so a host that had been given everything a
   --  program wrote still saw these go past it.

   procedure Write_Error
     (This    : Raven_VM'Class;
      Message : String);

   type Handle is private;

   function Is_Null (This : Handle) return Boolean;

   --  Giving a handle back.  Until this, the list they live in was
   --  only ever appended to, so every handle kept what it named for
   --  the rest of the session and every collection walked all of
   --  them.
   --
   --  The one released is left null, which Is_Null answers for.  A
   --  copy of it taken beforehand is not, and using one of those is
   --  the same fault as using anything else that has been given back.
   --
   --  One handle per call and one release each: asking twice for a
   --  handle on the same object gives two, and both want releasing.

   procedure Release
     (This  : Raven_VM;
      Value : in out Handle);

   function Bind_Name
     (This : Raven_VM;
      Name : String)
      return Handle;

   type Slot_Index is range 1 .. 16;

   --  What is in a slot, so that a host can find out before it asks.
   --  Every one of the getters below but the boolean one is wrong to
   --  call on the wrong kind of value, and there used to be no way of
   --  telling which was the right one: raven's own primitives ask
   --  Raven.Objects directly, which a host cannot reach.
   --
   --  A string is a value of the host's rather than of the machine's,
   --  and says so, because a host that is handed one almost always
   --  wants its characters.  Any other one says Foreign_Kind and
   --  wants To_Foreign_Value.
   --
   --  Other_Kind is for what a program cannot hold and a host has no
   --  business with -- an instruction, an undefined -- and is here so
   --  that this is a total answer rather than an error of its own.

   type Value_Kind is
     (Nil_Kind,
      Boolean_Kind,
      Integer_Kind,
      Float_Kind,
      Character_Kind,
      Symbol_Kind,
      String_Kind,
      Pair_Kind,
      Vector_Kind,
      Bytevector_Kind,
      Procedure_Kind,
      Eof_Kind,
      Foreign_Kind,
      Other_Kind);

   function Kind
     (This  : Raven_VM;
      Index : Slot_Index)
      return Value_Kind;

   --  What the value in a slot would be written as, whatever kind it
   --  is.  Readable says which of the two renderings is wanted, the
   --  way write and display differ.
   --
   --  Get_Slot returning a String used to do this for anything that
   --  was not a string, so a host asking for a string and given a
   --  list got a rendering of the list and no way to know.  It says
   --  so now, and this is where the old answer went.

   function Show_Slot
     (This     : Raven_VM;
      Index    : Slot_Index;
      Readable : Boolean := True)
      return String;

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Boolean;

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Integer;

   --  It is an error to ask for a string from a slot that does not
   --  hold one.  Ask Kind first.

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

   --  A string, which is what Get_Slot of one answers with.  This
   --  used to make a symbol of the name, so the two were not each
   --  other's opposite and there was no way at all to answer with a
   --  string.  Set_Slot_Symbol is where the symbol went.

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : String);

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Handle);

   --  And the same for an object, which is the whole of a value
   --  rather than one of the kinds above.  These are what a foreign
   --  value that holds something of the program's is written with: it
   --  takes one out of a slot, keeps it, hands it to Mark when the
   --  collector asks, and puts it back in a slot to answer with.
   --
   --  An object is only safe where the collector can find it: in a
   --  slot, or inside something whose Mark hands it over.  Kept in an
   --  Ada variable across anything that might allocate, it is wrong
   --  by the next collection and says nothing about it.  A handle is
   --  the answer where that is not good enough -- it is a root in its
   --  own right, and costs an entry in a table and a release.

   function Get_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index)
      return Object;

   procedure Set_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index;
      Value : Object);

   procedure Slot_Cons
     (This     : Raven_VM;
      Index    : Slot_Index;
      Car_Slot : Slot_Index);

   --  The kinds a slot could carry in neither direction: a float, a
   --  character, and a symbol, which is a name rather than a string
   --  and says so.
   --
   --  Each of these is wrong to call on the wrong kind and says so.
   --  Kind is how a host finds out first.

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Float;

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Wide_Wide_Character;

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Float);

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Wide_Wide_Character);

   function Symbol_Name
     (This  : Raven_VM;
      Index : Slot_Index)
      return String;

   procedure Set_Slot_Symbol
     (This  : Raven_VM;
      Index : Slot_Index;
      Name  : String);

   --  Taking a pair apart.  Slot_Cons could build one and nothing
   --  could read one, so a host handed a list could do nothing with
   --  it whatever.  Into may be Index, which is how a list is walked.

   procedure Slot_Car
     (This  : Raven_VM;
      Index : Slot_Index;
      Into  : Slot_Index);

   procedure Slot_Cdr
     (This  : Raven_VM;
      Index : Slot_Index;
      Into  : Slot_Index);

   procedure Slot_Set_Car
     (This  : Raven_VM;
      Index : Slot_Index;
      From  : Slot_Index);

   procedure Slot_Set_Cdr
     (This  : Raven_VM;
      Index : Slot_Index;
      From  : Slot_Index);

   --  Vectors.  Making one may collect, so it is made into a slot
   --  rather than handed back, and what goes in it comes from a slot
   --  for the same reason.

   procedure Slot_New_Vector
     (This   : Raven_VM;
      Index  : Slot_Index;
      Length : Natural);

   function Slot_Vector_Length
     (This  : Raven_VM;
      Index : Slot_Index)
      return Natural;

   procedure Slot_Vector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural;
      Into     : Slot_Index);

   procedure Slot_Set_Vector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural;
      From     : Slot_Index);

   --  Bytevectors, whose elements are bytes rather than values and so
   --  need no slot to travel in.

   procedure Slot_New_Bytevector
     (This   : Raven_VM;
      Index  : Slot_Index;
      Length : Natural);

   function Slot_Bytevector_Length
     (This  : Raven_VM;
      Index : Slot_Index)
      return Natural;

   function Slot_Bytevector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural)
      return Natural;

   procedure Slot_Set_Bytevector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural;
      Value    : Natural);

   --  equal?, which walks what it is given.  A host had the equality
   --  Ada gives a private type, which is eq?: two lists of the same
   --  numbers were not equal by it.

   function Slot_Equal
     (This         : Raven_VM;
      Left, Right  : Slot_Index)
      return Boolean;

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

   --  What this value holds that the collector must know about.
   --  Process is called with each object in it, and may replace it:
   --  the collector moves what it copies, so a value that keeps an
   --  object and does not hand it over here has it collected while it
   --  is still named, and left pointing into the half of the heap
   --  that was abandoned even when something else kept it alive.
   --
   --  Null for a value holding nothing of the machine's, which is
   --  every one raven has of its own.

   procedure Mark
     (This    : in out Foreign_Value_Instance;
      Process : not null access procedure (Value : in out Object))
   is null;

   --  Told when the collector has given this value up, so that
   --  whatever it stood for can be given back.
   --
   --  No VM: a collection is under way when this is called, and that
   --  is not the moment to call back into the machine.  So a value
   --  that keeps a handle cannot release it here, which is a reason
   --  to keep objects and a Mark rather than handles.  Wren's
   --  finalize has the same shape for the same reason.

   procedure Free (This : in out Foreign_Value_Instance) is null;

   function Equal (This : Foreign_Value_Instance;
                   To   : Foreign_Value_Instance)
                   return Boolean
                   is abstract;

   --  Making one of these values and getting it back.  Without them a
   --  host could derive from Foreign_Value_Instance and override
   --  every one of its operations and had no way to make one or to
   --  reach one it had been handed: the type was public and the two
   --  things to do with it were not.

   function Create_Foreign_Value
     (This  : Raven_VM'Class;
      Value : Foreign_Value_Instance'Class)
      return Object;

   function To_Foreign_Value
     (This  : Raven_VM'Class;
      Value : Object)
      return Foreign_Value_Instance'Class;

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

   --  Completing the private type above.  A child of Raven sees this
   --  and works with the bits; anything outside holds it and hands it
   --  to Mark.

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
