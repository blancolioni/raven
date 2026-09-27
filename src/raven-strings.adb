with Ada.Strings.Fixed;
with Raven.Objects;

package body Raven.Strings is

   procedure Display_Text (VM : Raven_VM);
   procedure Write_Text (VM : Raven_VM);
   procedure Is_String (VM : Raven_VM);
   procedure String_Length (VM : Raven_VM);
   procedure List_To_String (VM : Raven_VM);
   procedure String_To_List (VM : Raven_VM);
   procedure Enable_Trace (VM : Raven_VM);

   --  What can be done to a string by arithmetic, done by arithmetic.
   --  Each of these was written on string->list, which conses a pair
   --  for every character: string-ref of one character of a thousand
   --  made a thousand pairs, and a loop over a string made the square
   --  of its length.

   procedure Make_String (VM : Raven_VM);
   procedure String_Compare (VM : Raven_VM);
   procedure String_Ref (VM : Raven_VM);
   procedure Substring (VM : Raven_VM);

   --  The length of the string in this slot, or an error naming the
   --  procedure that was given something else.  It looks at the string
   --  where it is rather than copying it out to ask.

   function Checked_Length
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Natural;

   --------------------
   -- Checked_Length --
   --------------------

   function Checked_Length
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Natural
   is
      X      : constant Object := VM.Get_Slot (Slot);
      Length : Integer := -1;

      procedure Measure (Item : Foreign_Value_Instance'Class);

      -------------
      -- Measure --
      -------------

      procedure Measure (Item : Foreign_Value_Instance'Class) is
      begin
         if Item in Instance'Class then
            Length := Instance'Class (Item).Length;
         end if;
      end Measure;

   begin
      if Raven.Objects.Is_Foreign_Value (X) then
         VM.Query_Foreign_Value (X, Measure'Access);
      end if;

      if Length < 0 then
         raise Constraint_Error with
           Name & ": not a string: " & Encode (VM.Display (X));
      end if;

      return Length;
   end Checked_Length;

   -------------
   -- Display --
   -------------

   overriding function Display (This : Instance) return String is
   begin
      --  The characters and nothing else: the quotation marks and the
      --  escapes above are there for the reader and not for a person.

      return Encode (This.Value);
   end Display;

   -------------
   -- Display --
   -------------

   --  The two renderings, each as the text it comes to.  display and
   --  write in the library write that text; these are what they write.
   --
   --  R7RS has no way of asking for the text without writing it, so
   --  neither of these is a name a program is offered.  The harness
   --  asks for one, because a test that says what something writes as
   --  has to hold the answer to compare it.

   procedure Display_Text (VM : Raven_VM) is
      S : constant Wide_Wide_String :=
            VM.Display (VM.Get_Slot (1), Readable => False);
      V : constant Instance := (Foreign_Value_Instance with
                                Length => S'Length, Value => S);
   begin
      VM.Set_Slot (1, VM.Create_Foreign_Value (V));
   end Display_Text;

   ------------------
   -- Enable_Trace --
   ------------------

   procedure Enable_Trace (VM : Raven_VM) is
   begin
      if VM.Get_Slot (1) then
         VM.Set_Parameter ("trace-execution", "true");
      else
         VM.Set_Parameter ("trace-execution", "false");
      end if;
   end Enable_Trace;

   ----------------
   -- Get_String --
   ----------------

   function Get_String
     (VM   : Raven_VM;
      Slot : Slot_Index)
      return String
   is
      X : constant Object := VM.Get_Slot (Slot);
      S : constant Wide_Wide_String :=
            Instance'Class (VM.To_Foreign_Value (X)).Value;
   begin
      return Encode (S);
   end Get_String;

   ---------------
   -- Is_String --
   ---------------

   function Is_String (From : Foreign_Value_Instance'Class) return Boolean
   is (From in Instance'Class);

   ---------------
   -- Is_String --
   ---------------

   procedure Is_String (VM : Raven_VM) is
      use Raven.Objects;
      X : constant Object := VM.Get_Slot (1);
      B : constant Boolean :=
            Is_Foreign_Value (X)
              and then VM.To_Foreign_Value (X) in Instance'Class;
   begin
      VM.Set_Slot (1, B);
   end Is_String;

   ---------------
   -- Is_String --
   ---------------

   function Is_String
     (VM   : Raven_VM;
      Slot : Slot_Index)
      return Boolean
   is
      X      : constant Object := VM.Get_Slot (Slot);
      Result : Boolean := False;

      procedure Ask (Item : Foreign_Value_Instance'Class);

      ---------
      -- Ask --
      ---------

      procedure Ask (Item : Foreign_Value_Instance'Class) is
      begin
         Result := Item in Instance'Class;
      end Ask;

   begin
      if Raven.Objects.Is_Foreign_Value (X) then
         VM.Query_Foreign_Value (X, Ask'Access);
      end if;

      return Result;
   end Is_String;

   --------------------
   -- List_To_String --
   --------------------

   procedure List_To_String (VM : Raven_VM) is

      function To_String (List : Object) return Wide_Wide_String;

      ---------------
      -- To_String --
      ---------------

      function To_String (List : Object) return Wide_Wide_String is
         Last : Natural := 0;
         Result : Wide_Wide_String (1 .. 200);
         It     : Object := List;
      begin
         while It /= Objects.Nil
           and then Last < Result'Last
         loop
            Last := Last + 1;
            if Objects.Is_Character (VM.Car (It)) then
               Result (Last) := Objects.To_Character (VM.Car (It));
            else
               raise Constraint_Error with
                 "list->string: expected character at position" & Last'Image
                 & " of " & Encode (VM.Display (List));
            end if;
            It := VM.Cdr (It);
         end loop;
         if It /= Objects.Nil then
            return Result & To_String (It);
         else
            return Result (1 .. Last);
         end if;
      end To_String;

      S : constant Wide_Wide_String := To_String (VM.Get_Slot (1));
      V : constant Instance := (Foreign_Value_Instance with
                                Length => S'Length, Value => S);
   begin
      VM.Set_Slot (1, VM.Create_Foreign_Value (V));
   end List_To_String;

   -------------------------
   -- Load_String_Library --
   -------------------------

   procedure Load_String_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class)
   is
   begin
      Evaluator.Bind_Foreign_Function
        ("string?", Is_String'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-display-text", Display_Text'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-write-text", Write_Text'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-string-length", String_Length'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-list->string", List_To_String'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-string->list", String_To_List'Access, 3);
      Evaluator.Bind_Foreign_Function
        ("raven-enable-trace", Enable_Trace'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-make-string", Make_String'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-string-ref", String_Ref'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-substring", Substring'Access, 3);
      Evaluator.Bind_Foreign_Function
        ("raven-string-compare", String_Compare'Access, 2);
   end Load_String_Library;

   -----------------
   -- Make_String --
   -----------------

   procedure Make_String (VM : Raven_VM) is
      use Raven.Objects;
      Length : constant Integer := VM.Get_Slot (1);
      Fill   : constant Object := VM.Get_Slot (2);
   begin
      if Length < 0 then
         raise Constraint_Error with
           "make-string: a string cannot be "
           & Ada.Strings.Fixed.Trim (Length'Image, Ada.Strings.Left) & " long";
      end if;

      if not Is_Character (Fill) then
         raise Constraint_Error with
           "make-string: not a character: " & Encode (VM.Display (Fill));
      end if;

      declare
         V : constant Instance :=
               (Foreign_Value_Instance with
                Length => Length,
                Value  => [1 .. Length => To_Character (Fill)]);
      begin
         VM.Set_Slot (1, VM.Create_Foreign_Value (V));
      end;
   end Make_String;

   ----------
   -- Show --
   ----------

   overriding function Show (This : Instance) return String is

      --  A string written so that the reader can read it back, which
      --  means the quotation marks and an escape for everything that
      --  would end the string or be read as something else.  It used
      --  to be the quotation marks alone, so a string holding one of
      --  them wrote as something that would not read.

      Result : Wide_Wide_String (1 .. 2 * This.Value'Length + 2);
      Last   : Natural := 0;

      procedure Put (Ch : Wide_Wide_Character);

      ---------
      -- Put --
      ---------

      procedure Put (Ch : Wide_Wide_Character) is
      begin
         Last := Last + 1;
         Result (Last) := Ch;
      end Put;

   begin
      Put ('"');

      for Ch of This.Value loop
         case Wide_Wide_Character'Pos (Ch) is
            when 7  => Put ('\'); Put ('a');
            when 8  => Put ('\'); Put ('b');
            when 9  => Put ('\'); Put ('t');
            when 10 => Put ('\'); Put ('n');
            when 13 => Put ('\'); Put ('r');
            when 34 => Put ('\'); Put ('"');
            when 92 => Put ('\'); Put ('\');
            when others => Put (Ch);
         end case;
      end loop;

      Put ('"');
      return Encode (Result (1 .. Last));
   end Show;

   --------------------
   -- String_Compare --
   --------------------

   --  Less than nothing, nothing, or more than nothing, as the first
   --  string comes before the second, is the same, or comes after.  A
   --  string that matches another as far as it goes comes first, which
   --  is what "<" on two arrays says.

   procedure String_Compare (VM : Raven_VM) is
      Left   : constant Object := VM.Get_Slot (1);
      Right  : constant Object := VM.Get_Slot (2);
      Answer : Integer := 0;

      procedure With_Left (L : Foreign_Value_Instance'Class);

      ---------------
      -- With_Left --
      ---------------

      procedure With_Left (L : Foreign_Value_Instance'Class) is

         procedure With_Right (R : Foreign_Value_Instance'Class);

         ----------------
         -- With_Right --
         ----------------

         procedure With_Right (R : Foreign_Value_Instance'Class) is
            A : Wide_Wide_String renames Instance'Class (L).Value;
            B : Wide_Wide_String renames Instance'Class (R).Value;
         begin
            Answer := (if A < B then -1 elsif A = B then 0 else 1);
         end With_Right;

      begin
         VM.Query_Foreign_Value (Right, With_Right'Access);
      end With_Left;

      Left_Length  : constant Natural :=
                       Checked_Length (VM, "string comparison", 1);
      Right_Length : constant Natural :=
                       Checked_Length (VM, "string comparison", 2);
      pragma Unreferenced (Left_Length, Right_Length);
   begin
      VM.Query_Foreign_Value (Left, With_Left'Access);
      VM.Set_Slot (1, Answer);
   end String_Compare;

   -------------------
   -- String_Length --
   -------------------

   --  Without copying the string to measure it, which it did twice,
   --  once for an assertion: a loop that asks for the length of the
   --  string it walks would copy the string every time round.

   procedure String_Length (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Checked_Length (VM, "string-length", 1));
   end String_Length;

   ----------------
   -- String_Ref --
   ----------------

   procedure String_Ref (VM : Raven_VM) is
      Length : constant Natural := Checked_Length (VM, "string-ref", 1);
      Index  : constant Integer := VM.Get_Slot (2);
      Answer : Wide_Wide_Character;

      procedure Look (Item : Foreign_Value_Instance'Class);

      ----------
      -- Look --
      ----------

      procedure Look (Item : Foreign_Value_Instance'Class) is
         S : Wide_Wide_String renames Instance'Class (Item).Value;
      begin
         Answer := S (S'First + Index);
      end Look;

   begin
      if Index not in 0 .. Length - 1 then
         raise Constraint_Error with
           "string-ref:" & Index'Image & " is not an index of a string of"
           & Length'Image;
      end if;

      VM.Query_Foreign_Value (VM.Get_Slot (1), Look'Access);
      VM.Set_Slot (1, Raven.Objects.To_Object (Answer));
   end String_Ref;

   --------------------
   -- String_To_List --
   --------------------

   procedure String_To_List (VM : Raven_VM) is
      use Raven.Objects;
      X : constant Object := VM.Get_Slot (1);
      pragma Assert
        (Is_Foreign_Value (X)
         and then VM.To_Foreign_Value (X) in Instance'Class);

      --  A copy rather than a renaming of the value in the table.  The
      --  loop below allocates, so a collection can happen inside it,
      --  and what it would find is decided by the slots -- which is
      --  also why the string stays in slot 1 until the answer is put
      --  there, and why the list is built in a slot of its own.

      S : constant Wide_Wide_String :=
            Instance'Class (VM.To_Foreign_Value (X)).Value;

      --  Where to start and where to stop, which string->list has
      --  always taken and this has always ignored: it was bound as
      --  taking one argument, so (string->list "hello" 1 3) was the
      --  whole of "hello" and substring could not be written on it.

      First : constant Integer := VM.Get_Slot (2);
      Last  : constant Integer := VM.Get_Slot (3);
   begin
      if First < 0 or else Last > S'Length or else First > Last then
         raise Constraint_Error with
           "string->list:" & First'Image & Last'Image
           & " is not within a string of" & S'Length'Image;
      end if;

      VM.Set_Slot_Nil (4);

      for I in reverse S'First + First .. S'First + Last - 1 loop
         VM.Set_Slot (5, To_Object (S (I)));
         VM.Slot_Cons (4, 5);
      end loop;

      declare
         Answer : constant Object := VM.Get_Slot (4);
      begin
         VM.Set_Slot (1, Answer);
      end;
   end String_To_List;

   ---------------
   -- Substring --
   ---------------

   --  The characters from Start up to End, which is what substring and
   --  string-copy both are.  The slice is taken where the string is and
   --  made into a string of its own only after, because making one may
   --  collect and nothing may be made while the string is looked at.

   procedure Substring (VM : Raven_VM) is
      Length : constant Natural := Checked_Length (VM, "substring", 1);
      First  : constant Integer := VM.Get_Slot (2);
      Last   : constant Integer := VM.Get_Slot (3);
   begin
      if First < 0 or else Last > Length or else First > Last then
         raise Constraint_Error with
           "substring:" & First'Image & Last'Image
           & " is not within a string of" & Length'Image;
      end if;

      declare
         Slice : Wide_Wide_String (1 .. Last - First);

         procedure Take (Item : Foreign_Value_Instance'Class);

         ----------
         -- Take --
         ----------

         procedure Take (Item : Foreign_Value_Instance'Class) is
            S : Wide_Wide_String renames Instance'Class (Item).Value;
         begin
            Slice := S (S'First + First .. S'First + Last - 1);
         end Take;

      begin
         VM.Query_Foreign_Value (VM.Get_Slot (1), Take'Access);

         declare
            V : constant Instance := (Foreign_Value_Instance with
                                      Length => Slice'Length,
                                      Value  => Slice);
         begin
            VM.Set_Slot (1, VM.Create_Foreign_Value (V));
         end;
      end;
   end Substring;

   ----------
   -- Text --
   ----------

   function Text (From : Foreign_Value_Instance'Class) return String
   is (Encode (Instance'Class (From).Value));

   --------------
   -- To_Value --
   --------------

   function To_Value (Text : Wide_Wide_String) return Instance
   is (Foreign_Value_Instance with
       Length => Text'Length, Value => Text);

   ------------------
   -- Write_String --
   ------------------

   procedure Write_String
     (VM   : Raven_VM;
      Slot : Slot_Index;
      S    : String)
   is
      W : constant Wide_Wide_String := Decode (S);
      V : constant Instance := (Foreign_Value_Instance with
                                Length => W'Length, Value => W);
   begin
      VM.Set_Slot (Slot, VM.Create_Foreign_Value (V));
   end Write_String;

   ----------------
   -- Write_Text --
   ----------------

   procedure Write_Text (VM : Raven_VM) is
      S : constant Wide_Wide_String :=
            VM.Display (VM.Get_Slot (1), Readable => True);
      V : constant Instance := (Foreign_Value_Instance with
                                Length => S'Length, Value => S);
   begin
      VM.Set_Slot (1, VM.Create_Foreign_Value (V));
   end Write_Text;

end Raven.Strings;
