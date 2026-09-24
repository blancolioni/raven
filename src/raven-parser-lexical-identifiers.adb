with Ada.Wide_Wide_Characters.Handling;

package body Raven.Parser.Lexical.Identifiers is

   type State_Type is (Start, Scanning_Integer, Base_Prefix,
                       Number_Sign, Leading_Dot,
                       Decimal_Point, Scanning_Decimals,
                       Exponent, Exponent_Sign, Scanning_Exponent,
                       End_State_Identifier,
                       End_State_Integer,
                       End_State_Float);

   subtype End_State is State_Type range
     End_State_Identifier .. End_State_Float;

   type Integer_Base is range 2 .. 16;

   function Is_Base_Digit
     (Ch   : Wide_Wide_Character;
      Base : Integer_Base)
      return Boolean;

   function Scan_Identifier
     (Id        : Wide_Wide_String;
      Call_Back : access
        procedure (State : State_Type;
                   Ch    : Wide_Wide_Character))
      return End_State;

   -------------------------
   -- Classify_Identifier --
   -------------------------

   function Classify_Identifier
     (Id : Wide_Wide_String)
      return Raven.Parser.Tokens.Token
   is
      Final_State : constant End_State :=
                      Scan_Identifier (Id, null);

   begin
      case Final_State is
         when End_State_Identifier =>
            return Tok_Identifier;
         when End_State_Integer =>
            return Tok_Integer;
         when End_State_Float =>
            return Tok_Float;
      end case;
   end Classify_Identifier;

   -------------------
   -- Is_Base_Digit --
   -------------------

   function Is_Base_Digit
     (Ch   : Wide_Wide_Character;
      Base : Integer_Base)
      return Boolean
   is
      use Ada.Wide_Wide_Characters.Handling;
   begin
      case Base is
         when 2 =>
            return Ch = '0' or else Ch = '1';
         when 8 =>
            return Ch in '0' .. '7';
         when 10 =>
            return Is_Digit (Ch);
         when 16 =>
            return Is_Digit (Ch)
              or else Ch in 'A' .. 'F'
              or else Ch in 'a' .. 'f';
         when others =>
            raise Program_Error with
              "bad base";
      end case;
   end Is_Base_Digit;

   ---------------------
   -- Scan_Identifier --
   ---------------------

   function Scan_Identifier
     (Id        : Wide_Wide_String;
      Call_Back : access
        procedure (State : State_Type;
                   Ch    : Wide_Wide_Character))
      return End_State
   is
      use Ada.Wide_Wide_Characters.Handling;

      Base   : Integer_Base := 10;
      State  : State_Type := Start;

   begin
      for I in Id'Range loop
         if Call_Back /= null then
            Call_Back (State, Id (I));
         end if;
         exit when State in End_State;
         declare
            Ch   : constant Wide_Wide_Character := Id (I);
            Last : constant Boolean := I = Id'Last;
         begin
            case State is
               when Start =>
                  if Ch = '#' then
                     State := Base_Prefix;
                  elsif Ch = '+' or else Ch = '-' then
                     State := Number_Sign;
                  elsif Ch = '.' then

                     --  A decimal written without the zero in front of
                     --  it.  A number could only begin with a digit, a
                     --  sign or a #, so .5 was a name.  A lone dot
                     --  still is, and so is ... , because what decides
                     --  is the digit after it.

                     if Last then
                        State := End_State_Identifier;
                     else
                        State := Leading_Dot;
                     end if;
                  elsif Is_Digit (Ch) then
                     if Last then
                        State := End_State_Integer;
                     else
                        State := Scanning_Integer;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;
               when Number_Sign =>
                  if Ch = '#' then
                     State := Base_Prefix;
                  elsif Ch = '.' then
                     if Last then
                        State := End_State_Identifier;
                     else
                        State := Leading_Dot;
                     end if;
                  elsif Is_Digit (Ch) then
                     if Last then
                        State := End_State_Integer;
                     else
                        State := Scanning_Integer;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;
               when Scanning_Integer =>
                  if Ch = '.' then
                     State := Decimal_Point;
                     if Base /= 10 then
                        State := End_State_Identifier;
                     elsif Last then
                        State := End_State_Float;
                     end if;
                  elsif Base = 10
                    and then (Ch = 'e' or else Ch = 'E')
                  then

                     --  An exponent used to be reachable only through
                     --  a decimal point, so 1e20 stopped being a
                     --  number at the e and came back a name.  Base
                     --  ten is asked about because e is a digit of
                     --  base sixteen, where this is not an exponent at
                     --  all; the test above this one has already sent
                     --  a hex number's digits to Is_Base_Digit.

                     if Last then
                        State := End_State_Identifier;
                     else
                        State := Exponent;
                     end if;
                  elsif not Is_Base_Digit (Ch, Base) then
                     State := End_State_Identifier;
                  elsif Last then
                     State := End_State_Integer;
                  end if;
               when Leading_Dot =>
                  if Is_Digit (Ch) then
                     if Last then
                        State := End_State_Float;
                     else
                        State := Scanning_Decimals;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;
               when Decimal_Point =>
                  if Is_Digit (Ch) then
                     if Last then
                        State := End_State_Float;
                     else
                        State := Scanning_Decimals;
                     end if;
                  elsif Ch = 'e' or else Ch = 'E' then
                     if Last then
                        State := End_State_Identifier;
                     else
                        State := Exponent;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;
               when Scanning_Decimals =>
                  if Is_Digit (Ch) then
                     if Last then
                        State := End_State_Float;
                     end if;
                  elsif Ch = 'e' or else Ch = 'E' then
                     if Last then
                        State := End_State_Identifier;
                     else
                        State := Exponent;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;

               when Exponent =>
                  if Ch = '+' or else Ch = '-' then
                     if Last then
                        State := End_State_Identifier;
                     else
                        State := Exponent_Sign;
                     end if;
                  elsif Is_Digit (Ch) then
                     if Last then
                        State := End_State_Float;
                     else
                        State := Scanning_Exponent;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;
               when Exponent_Sign =>
                  if Is_Digit (Ch) then
                     if Last then
                        State := End_State_Float;
                     else
                        State := Scanning_Exponent;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;

               when Scanning_Exponent =>
                  if Is_Digit (Ch) then
                     if Last then
                        State := End_State_Float;
                     end if;
                  else
                     State := End_State_Identifier;
                  end if;
               when Base_Prefix =>
                  if Ch = 'o' then
                     Base := 8;
                     State := Scanning_Integer;
                  elsif Ch = 'b' then
                     Base := 2;
                     State := Scanning_Integer;
                  elsif Ch = 'd' then
                     Base := 10;
                     State := Scanning_Integer;
                  elsif Ch = 'x' then
                     Base := 16;
                     State := Scanning_Integer;
                  else
                     State := End_State_Identifier;
                  end if;
               when End_State =>
                  null;
            end case;
         end;
      end loop;

      if State in End_State then
         return State;
      else
         return End_State_Identifier;
      end if;

   end Scan_Identifier;

end Raven.Parser.Lexical.Identifiers;
