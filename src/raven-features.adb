with Ada.Containers.Indefinite_Vectors;

with Raven_Config;

package body Raven.Features is

   package String_Vectors is
     new Ada.Containers.Indefinite_Vectors (Positive, String);

   --  The machine and operating system Alire built for, in the names
   --  R7RS's appendix uses: x86-64 where Alire says x86_64, and posix
   --  and unix beside the name of a system that is both.

   function Arch_Features return String_Vectors.Vector;
   function OS_Features return String_Vectors.Vector;

   function Build return String_Vectors.Vector;

   -------------------
   -- Arch_Features --
   -------------------

   --  The configuration is a constant, so every branch but one is known
   --  to be dead where it is compiled.  Which one is decided by where
   --  it is built, and that is the point.

   pragma Warnings (Off, "condition is always *");

   function Arch_Features return String_Vectors.Vector is
      Arch : constant String := Raven_Config.Alire_Host_Arch;
   begin
      return Result : String_Vectors.Vector do
         if Arch = "x86_64" then
            Result.Append ("x86-64");
         elsif Arch = "aarch64" then
            Result.Append ("arm64");
         elsif Arch /= "" then
            Result.Append (Arch);
         end if;
      end return;
   end Arch_Features;

   pragma Warnings (On, "condition is always *");

   -----------
   -- Build --
   -----------

   function Build return String_Vectors.Vector is
   begin
      return Result : String_Vectors.Vector do
         Result.Append ("raven");
         Result.Append ("raven-" & Raven_Config.Crate_Version);

         --  A string and a character hold any code point.

         Result.Append ("full-unicode");

         --  +, -, * and expt to a whole power give exact answers for
         --  exact arguments, however large: an integer past a fixnum is
         --  a bignum (#102) rather than an overflow.

         Result.Append ("exact-closed");

         Result.Append_Vector (OS_Features);
         Result.Append_Vector (Arch_Features);
      end return;
   end Build;

   --  Filled once the bodies it is built from exist, which is at the
   --  end of this package's elaboration and not at this declaration.

   All_Features : String_Vectors.Vector;

   -----------
   -- Count --
   -----------

   function Count return Natural
   is (Natural (All_Features.Length));

   -------------
   -- Feature --
   -------------

   function Feature (Index : Positive) return String
   is (All_Features (Index));

   ----------------
   -- Is_Feature --
   ----------------

   function Is_Feature (Name : String) return Boolean
   is (All_Features.Contains (Name));

   -----------------
   -- OS_Features --
   -----------------

   --  The configuration is a constant, so every branch but one is known
   --  to be dead where it is compiled.  Which one is decided by where
   --  it is built, and that is the point.

   pragma Warnings (Off, "condition is always *");

   function OS_Features return String_Vectors.Vector is
      OS : constant String := Raven_Config.Alire_Host_OS;
   begin
      return Result : String_Vectors.Vector do
         if OS = "windows" then
            Result.Append ("windows");
         elsif OS = "linux" then
            Result.Append ("posix");
            Result.Append ("unix");
            Result.Append ("linux");
         elsif OS = "macos" then
            Result.Append ("posix");
            Result.Append ("unix");
            Result.Append ("darwin");
         elsif OS = "freebsd" then
            Result.Append ("posix");
            Result.Append ("unix");
            Result.Append ("freebsd");
         elsif OS /= "" then
            Result.Append (OS);
         end if;
      end return;
   end OS_Features;

   pragma Warnings (On, "condition is always *");

begin
   All_Features := Build;
end Raven.Features;
