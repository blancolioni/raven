with Raven.Objects;

package body Raven.Strings is

   procedure Display (VM : Raven_VM);
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

   procedure Display (VM : Raven_VM) is
      S : constant Wide_Wide_String := VM.Display (VM.Get_Slot (1));
      V : constant Instance := (Foreign_Value_Instance with
                                Length => S'Length, Value => S);
   begin
      VM.Set_Slot (1, VM.Create_Foreign_Value (V));
   end Display;

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
        ("display", Display'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-string-length", String_Length'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-list->string", List_To_String'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-string->list", String_To_List'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-enable-trace", Enable_Trace'Access, 1);
   end Load_String_Library;

   ----------
   -- Show --
   ----------

   overriding function Show (This : Instance) return String is
   begin
      return '"' & Encode (This.Value) & '"';
   end Show;

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
      S renames Instance'Class (VM.To_Foreign_Value (X)).Value;
   begin
      VM.Set_Slot_Nil (1);
      for Ch of reverse S loop
         VM.Set_Slot (2, To_Object (Ch));
         VM.Slot_Cons (1, 2);
      end loop;
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
