with Raven.Objects;

package body Raven.Strings is

   procedure Display_Text (VM : Raven_VM);
   procedure Write_Text (VM : Raven_VM);
   procedure Is_String (VM : Raven_VM);
   procedure String_Length (VM : Raven_VM);
   procedure List_To_String (VM : Raven_VM);
   procedure String_To_List (VM : Raven_VM);
   procedure Enable_Trace (VM : Raven_VM);

   ---------------
   -- Is_String --
   ---------------

   function Is_String (From : Foreign_Value_Instance'Class) return Boolean
   is (From in Instance'Class);

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
      X : constant Object := VM.Get_Slot (Slot);
   begin
      return Raven.Objects.Is_Foreign_Value (X)
        and then VM.To_Foreign_Value (X) in Instance'Class;
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
   end Load_String_Library;

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

   -------------
   -- Display --
   -------------

   overriding function Display (This : Instance) return String is
   begin
      --  The characters and nothing else: the quotation marks and the
      --  escapes above are there for the reader and not for a person.

      return Encode (This.Value);
   end Display;

   -------------------
   -- String_Length --
   -------------------

   procedure String_Length (VM : Raven_VM) is
      use Raven.Objects;
      X : constant Object := VM.Get_Slot (1);
      pragma Assert
        (Is_Foreign_Value (X)
         and then VM.To_Foreign_Value (X) in Instance'Class);
   begin
      VM.Set_Slot (1, Instance'Class (VM.To_Foreign_Value (X)).Length);
   end String_Length;

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

end Raven.Strings;
