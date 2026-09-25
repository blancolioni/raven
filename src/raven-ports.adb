with Ada.Strings.Wide_Wide_Unbounded;

with Raven.Objects;
with Raven.Strings;

package body Raven.Ports is

   use Ada.Strings.Wide_Wide_Unbounded;

   type Port_Id is range 1 .. 999;

   --  The three the host owns, which keep their places so that asking
   --  for one twice answers with the same port.

   Host_Output : constant Port_Id := 1;
   Host_Error  : constant Port_Id := 2;
   Host_Input  : constant Port_Id := 3;

   First_Free  : constant Port_Id := 4;

   type Port_Direction is (Input, Output);

   type Port_Record is
      record
         Used      : Boolean := False;
         Direction : Port_Direction := Output;
         Open      : Boolean := True;
         Of_Host   : Boolean := False;
         Errors    : Boolean := False;
         Text      : Unbounded_Wide_Wide_String;
         Next      : Positive := 1;
      end record;

   Table : array (Port_Id) of Port_Record;

   type Instance is new Foreign_Value_Instance with
      record
         Id : Port_Id;
      end record;

   overriding function Show (This : Instance) return String;

   overriding procedure Free (This : in out Instance);

   overriding function Equal
     (This : Instance;
      To   : Instance)
      return Boolean
   is (This.Id = To.Id);

   procedure Close_Port (VM : Raven_VM);
   procedure Eof_Object (VM : Raven_VM);
   procedure Get_Output_String (VM : Raven_VM);
   procedure Is_Input_Port (VM : Raven_VM);
   procedure Is_Open (VM : Raven_VM);
   procedure Is_Output_Port (VM : Raven_VM);
   procedure Is_Port (VM : Raven_VM);
   procedure Open_Input_String (VM : Raven_VM);
   procedure Open_Output_String (VM : Raven_VM);
   procedure Port_Peek_Char (VM : Raven_VM);
   procedure Port_Read_Char (VM : Raven_VM);
   procedure Port_Ready (VM : Raven_VM);
   procedure Port_Write_Char (VM : Raven_VM);
   procedure Standard_Port (VM : Raven_VM);

   function Make_Port
     (VM : Raven_VM;
      Id : Port_Id)
      return Object;

   function Port_Of
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Port_Id;

   function New_Id return Port_Id;

   ----------------
   -- Close_Port --
   ----------------

   procedure Close_Port (VM : Raven_VM) is
      Id : constant Port_Id := Port_Of (VM, "close-port", 1);
   begin
      --  A port of the host's stays open: closing what the host reads
      --  and writes is not this program's to do.

      if not Table (Id).Of_Host then
         Table (Id).Open := False;
      end if;
   end Close_Port;

   -----------------------
   -- Get_Output_String --
   -----------------------

   procedure Get_Output_String (VM : Raven_VM) is
      Id : constant Port_Id := Port_Of (VM, "get-output-string", 1);
   begin
      if Table (Id).Direction /= Output or else Table (Id).Of_Host then
         raise Constraint_Error with
           "get-output-string: not a port opened on a string";
      end if;

      Raven.Strings.Write_String
        (VM, 1, Encode (To_Wide_Wide_String (Table (Id).Text)));
   end Get_Output_String;

   ----------------
   -- Eof_Object --
   ----------------

   procedure Eof_Object (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Raven.Objects.Eof);
   end Eof_Object;

   ----------
   -- Free --
   ----------

   overriding procedure Free (This : in out Instance) is
   begin
      --  What the collector has stopped naming, given back.  The
      --  host's own three are not, because they are not named by
      --  anything either and must go on answering.

      if not Table (This.Id).Of_Host then
         Table (This.Id) := (others => <>);
      end if;
   end Free;

   ---------------
   -- Is_Input_Port --
   ---------------

   procedure Is_Input_Port (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
      B : constant Boolean :=
            Raven.Objects.Is_Foreign_Value (X)
              and then VM.To_Foreign_Value (X) in Instance'Class
              and then Table (Instance'Class (VM.To_Foreign_Value (X)).Id)
                .Direction = Input;
   begin
      VM.Set_Slot (1, B);
   end Is_Input_Port;

   -------------
   -- Is_Open --
   -------------

   procedure Is_Open (VM : Raven_VM) is
      Id : constant Port_Id := Port_Of (VM, "port-open?", 1);
   begin
      VM.Set_Slot (1, Table (Id).Open);
   end Is_Open;

   ----------------------
   -- Is_Output_Port --
   ----------------------

   procedure Is_Output_Port (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
      B : constant Boolean :=
            Raven.Objects.Is_Foreign_Value (X)
              and then VM.To_Foreign_Value (X) in Instance'Class
              and then Table (Instance'Class (VM.To_Foreign_Value (X)).Id)
                .Direction = Output;
   begin
      VM.Set_Slot (1, B);
   end Is_Output_Port;

   -------------
   -- Is_Port --
   -------------

   procedure Is_Port (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
      B : constant Boolean :=
            Raven.Objects.Is_Foreign_Value (X)
              and then VM.To_Foreign_Value (X) in Instance'Class;
   begin
      VM.Set_Slot (1, B);
   end Is_Port;

   -----------------------
   -- Load_Port_Library --
   -----------------------

   procedure Load_Port_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class)
   is
   begin
      Table (Host_Output) :=
        (Used => True, Direction => Output, Of_Host => True, others => <>);
      Table (Host_Error) :=
        (Used => True, Direction => Output, Of_Host => True,
         Errors => True, others => <>);
      Table (Host_Input) :=
        (Used => True, Direction => Input, Of_Host => True, others => <>);

      Evaluator.Bind_Foreign_Function
        ("raven-eof-object", Eof_Object'Access, 0);
      Evaluator.Bind_Foreign_Function
        ("port?", Is_Port'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("input-port?", Is_Input_Port'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("output-port?", Is_Output_Port'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-standard-port", Standard_Port'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("open-input-string", Open_Input_String'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("open-output-string", Open_Output_String'Access, 0);
      Evaluator.Bind_Foreign_Function
        ("get-output-string", Get_Output_String'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-port-open?", Is_Open'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-close-port", Close_Port'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-write-char-to", Port_Write_Char'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-read-char", Port_Read_Char'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-peek-char", Port_Peek_Char'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-char-ready?", Port_Ready'Access, 1);
   end Load_Port_Library;

   ---------------
   -- Make_Port --
   ---------------

   function Make_Port
     (VM : Raven_VM;
      Id : Port_Id)
      return Object
   is (VM.Create_Foreign_Value (Instance'(Foreign_Value_Instance with Id)));

   ------------
   -- New_Id --
   ------------

   function New_Id return Port_Id is
   begin
      for Id in First_Free .. Port_Id'Last loop
         if not Table (Id).Used then
            return Id;
         end if;
      end loop;

      raise Constraint_Error with
        "no room for another port:" & Port_Id'Last'Image & " are open";
   end New_Id;

   -----------------------
   -- Open_Input_String --
   -----------------------

   procedure Open_Input_String (VM : Raven_VM) is
   begin
      if not Raven.Strings.Is_String (VM, 1) then
         raise Constraint_Error with
           "open-input-string: not a string: "
           & Encode (VM.Display (VM.Get_Slot (1)));
      end if;

      declare
         Text : constant Wide_Wide_String :=
                  Decode (Raven.Strings.Get_String (VM, 1));
         Id   : constant Port_Id := New_Id;
      begin
         Table (Id) :=
           (Used      => True,
            Direction => Input,
            Text      => To_Unbounded_Wide_Wide_String (Text),
            others    => <>);

         VM.Set_Slot (1, Make_Port (VM, Id));
      end;
   end Open_Input_String;

   ------------------------
   -- Open_Output_String --
   ------------------------

   procedure Open_Output_String (VM : Raven_VM) is
      Id : constant Port_Id := New_Id;
   begin
      Table (Id) := (Used => True, Direction => Output, others => <>);
      VM.Set_Slot (1, Make_Port (VM, Id));
   end Open_Output_String;

   ---------------------
   -- Port_Peek_Char --
   ---------------------

   procedure Port_Peek_Char (VM : Raven_VM) is
      Id : constant Port_Id := Port_Of (VM, "peek-char", 1);
   begin
      if Table (Id).Direction /= Input then
         raise Constraint_Error with "peek-char: not an input port";
      end if;

      if not Table (Id).Open then
         raise Constraint_Error with "peek-char: the port is closed";
      end if;

      --  A peek of the host's input is a read that is put back, which
      --  there is nowhere to put, so it is kept here instead: the
      --  character is read and left where the next read will find it.

      if Table (Id).Of_Host then
         Port_Read_Char (VM);

         declare
            Answer : constant Object := VM.Get_Slot (1);
         begin
            if not Raven.Objects.Is_Eof (Answer) then
               Table (Id).Text :=
                 To_Unbounded_Wide_Wide_String
                   ([Raven.Objects.To_Character (Answer)]);
               Table (Id).Next := 1;
            end if;
         end;

         return;
      end if;

      if Table (Id).Next > Length (Table (Id).Text) then
         VM.Set_Slot (1, Raven.Objects.Eof);
      else
         VM.Set_Slot
           (1,
            Raven.Objects.To_Object (Element (Table (Id).Text,
                                              Table (Id).Next)));
      end if;
   end Port_Peek_Char;

   --------------------
   -- Port_Read_Char --
   --------------------

   procedure Port_Read_Char (VM : Raven_VM) is
      Id : constant Port_Id := Port_Of (VM, "read-char", 1);
   begin
      if Table (Id).Direction /= Input then
         raise Constraint_Error with "read-char: not an input port";
      end if;

      if not Table (Id).Open then
         raise Constraint_Error with "read-char: the port is closed";
      end if;

      --  Whatever a peek left behind is read first, wherever the port
      --  reads from.

      if Table (Id).Next <= Length (Table (Id).Text) then
         VM.Set_Slot
           (1,
            Raven.Objects.To_Object (Element (Table (Id).Text,
                                              Table (Id).Next)));
         Table (Id).Next := Table (Id).Next + 1;

         if Table (Id).Of_Host then
            Table (Id).Text := Null_Unbounded_Wide_Wide_String;
            Table (Id).Next := 1;
         end if;

         return;
      end if;

      if not Table (Id).Of_Host then
         VM.Set_Slot (1, Raven.Objects.Eof);
         return;
      end if;

      declare
         Ch        : Wide_Wide_Character;
         Available : Boolean;
      begin
         VM.Read_Character (Ch, Available);

         if Available then
            VM.Set_Slot (1, Raven.Objects.To_Object (Ch));
         else
            VM.Set_Slot (1, Raven.Objects.Eof);
         end if;
      end;
   end Port_Read_Char;

   ----------------
   -- Port_Ready --
   ----------------

   procedure Port_Ready (VM : Raven_VM) is
      Id : constant Port_Id := Port_Of (VM, "char-ready?", 1);
   begin
      --  A string port always has its answer ready: it is all there
      --  already.  The host's has one ready only when a peek has left
      --  a character behind, because finding out otherwise would mean
      --  asking the host, and asking the host is the read that this
      --  is asked in order to avoid.

      VM.Set_Slot (1, not Table (Id).Of_Host
                   or else Table (Id).Next <= Length (Table (Id).Text));
   end Port_Ready;

   -------------
   -- Port_Of --
   -------------

   function Port_Of
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Port_Id
   is
      X : constant Object := VM.Get_Slot (Slot);
   begin
      if not Raven.Objects.Is_Foreign_Value (X)
        or else not (VM.To_Foreign_Value (X) in Instance'Class)
      then
         raise Constraint_Error with
           Name & ": not a port: " & Encode (VM.Display (X));
      end if;

      return Instance'Class (VM.To_Foreign_Value (X)).Id;
   end Port_Of;

   ---------------------
   -- Port_Write_Char --
   ---------------------

   procedure Port_Write_Char (VM : Raven_VM) is
      Ch : constant Object := VM.Get_Slot (1);
      Id : constant Port_Id := Port_Of (VM, "write-char", 2);
   begin
      if Table (Id).Direction /= Output then
         raise Constraint_Error with "write-char: not an output port";
      end if;

      if not Table (Id).Open then
         raise Constraint_Error with "write-char: the port is closed";
      end if;

      if Table (Id).Of_Host then
         VM.Write_Character (Raven.Objects.To_Character (Ch),
                             Errors => Table (Id).Errors);
      else
         Append (Table (Id).Text, Raven.Objects.To_Character (Ch));
      end if;
   end Port_Write_Char;

   ----------
   -- Show --
   ----------

   overriding function Show (This : Instance) return String is
   begin
      return (if Table (This.Id).Direction = Input
              then "#input-port"
              else "#output-port");
   end Show;

   -------------------
   -- Standard_Port --
   -------------------

   procedure Standard_Port (VM : Raven_VM) is
      Which : constant Integer := VM.Get_Slot (1);
   begin
      --  The library asks for these three by number and nothing else
      --  should ask at all; without this, asking for any other number
      --  handed out a port on a place in the table that no one had
      --  opened.

      if Which not in Integer (Host_Output) .. Integer (Host_Input) then
         raise Constraint_Error with
           "raven-standard-port: no such port:" & Which'Image;
      end if;

      VM.Set_Slot (1, Make_Port (VM, Port_Id (Which)));
   end Standard_Port;

end Raven.Ports;
