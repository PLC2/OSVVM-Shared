--
--  File Name:         TbAb_Interrupt3.vhd
--  Design Unit Name:  Architecture of TestCtrl
--  Revision:          OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      Test transaction source
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    10/2022   2022.10    Updated for new interrupt handler
--    04/2021   2021.04    Initial revision
--
--
--  This file is part of OSVVM.
--  
--  Copyright (c) 2021-2022 by SynthWorks Design Inc.  
--  
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--  
--      https://www.apache.org/licenses/LICENSE-2.0
--  
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--  

architecture Interrupt3 of TestCtrl is

  signal ManagerSync1, MemorySync1, TestDone, GenerateIntSync1, GenerateIntSync2 : integer_barrier := 1 ;
 
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
    SetTestName("TbAb_Interrupt3") ;
    SetLogEnable(PASSED, TRUE) ;    -- Enable PASSED logs
    SetLogEnable(INFO, TRUE) ;    -- Enable INFO logs
    SetLogEnable(GetAlertLogID("Memory_1"), INFO, FALSE) ;   

    -- Wait for testbench initialization 
    wait for 0 ns ;  wait for 0 ns ;
    TranscriptOpen ;
    SetTranscriptMirror(TRUE) ; 

    -- Wait for Design Reset
    wait until nReset = '1' ;  
    ClearAlerts ;

    -- Wait for test to finish
    WaitForBarrier(TestDone, 35 ms) ;
    AlertIf(now >= 35 ms, "Test finished due to timeout") ;
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");
    
    
    TranscriptClose ; 
    -- Printing differs in different simulators due to differences in process order execution
    -- AlertIfDiff("./results/TbAb_Interrupt3.txt", "../AXI4/Axi4/testbench/validated_results/TbAb_Interrupt3.txt", "") ; 

    EndOfTestReports ; 
    std.env.stop ; 
    wait ; 
  end process ControlProc ; 

  ------------------------------------------------------------
  -- ManagerProc
  --   Generate transactions for AxiManager
  ------------------------------------------------------------
  ManagerProc : process
    variable Data : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) := (others => '0') ;    
  begin
    wait until nReset = '1' ;  
    WaitForClock(ManagerRec, 2) ; 
    
    for i in 0 to 7 loop 
      blankline(2) ; 
      log("Main Starting Writes.  Loop #" & to_string(i)) ;
      Write(ManagerRec, X"1000_0000", Data ) ;
      Write(ManagerRec, X"1000_0004", Data + 1 ) ;
      Write(ManagerRec, X"1000_0008", Data + 2 ) ;
      Write(ManagerRec, X"1000_000C", Data + 3 ) ;
      
      -- Do Write and Read Cycles mixed with Interrupt Handling
--      IntReq <= '1' after i * 10 ns + 5 ns, '0' after i * 10 ns + 50 ns ;  
      if i mod 2 = 0 then 
        WaitForBarrier(GenerateIntSync1) ; 
      else
        WaitForBarrier(GenerateIntSync2) ; 
      end if ; 
      wait for 9 ns ; 
      Write(ManagerRec, X"1000_0010", Data + 4 ) ;
      ReadCheck(ManagerRec, X"1000_0010", Data + 4 ) ;
      Write(ManagerRec, X"1000_0014", Data + 5 ) ;
      ReadCheck(ManagerRec, X"1000_0014", Data + 5 ) ;
      WaitForClock(ManagerRec, 1) ; 
      log("WaitForClock #1 finished") ;
      WaitForClock(ManagerRec, 1) ; 
      log("WaitForClock #2 finished") ;

      blankline(2) ; 
      log("Main Starting Reads.  Loop #" & to_string(i)) ;
      ReadCheck(ManagerRec, X"A000_2000", Data ) ;
      ReadCheck(ManagerRec, X"A000_2004", Data + 1 ) ;
      ReadCheck(ManagerRec, X"A000_2008", Data + 2 ) ;
      ReadCheck(ManagerRec, X"A000_200C", Data + 3 ) ;

      Data := Data + X"10" ;
    end loop ; 

    -- Wait for outputs to propagate and signal TestDone
    WaitForClock(ManagerRec, 2) ;
    WaitForBarrier(TestDone) ;
    wait ;
  end process ManagerProc ;


  ------------------------------------------------------------
  -- InterruptProc
  --   Generate transactions for AxiSubordinate
  ------------------------------------------------------------
  InterruptProc : process
    variable Data : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) := (others => '0') ;    
  begin
    WaitForClock(InterruptRec, 1) ; 
    blankline(2) ; 
    log("Interrupt Handler Started") ; 
    ReadCheck(InterruptRec, X"1000_0000", Data ) ;
    ReadCheck(InterruptRec, X"1000_0004", Data + 1 ) ;
    ReadCheck(InterruptRec, X"1000_0008", Data + 2 ) ;
    ReadCheck(InterruptRec, X"1000_000C", Data + 3 ) ;
    
    Write(InterruptRec, X"A000_2000", Data ) ;
    Write(InterruptRec, X"A000_2004", Data + 1 ) ;
    Write(InterruptRec, X"A000_2008", Data + 2 ) ;
    Write(InterruptRec, X"A000_200C", Data + 3 ) ;
    
    Data := Data + X"10" ;

    log("Interrupt Handler Done") ; 
    blankline(2) ; 
    InterruptReturn(InterruptRec) ;
    wait for 0 ns ; 
  end process InterruptProc ;

  ------------------------------------------------------------
  -- InterruptGeneratorProc1
  --   Generate transactions for AxiSubordinate
  ------------------------------------------------------------
  GenInterruptProc1 : process
    variable IterationCount : integer := 0 ; 
  begin
    WaitForBarrier(GenerateIntSync1) ; 
    -- IntReq <= '1' after IterationCount * 10 ns + 5 ns, '0' after IterationCount * 10 ns + 50 ns ;
    wait for IterationCount * 10 ns + 5 ns ;
    Send(InterruptRecArray(0), "1") ; 
    wait for 45 ns ;
    Send(InterruptRecArray(0), "0") ; 
    
    IterationCount := IterationCount + 2 ; 
  end process GenInterruptProc1 ;

  ------------------------------------------------------------
  -- InterruptGeneratorProc2
  --   Generate transactions for AxiSubordinate
  ------------------------------------------------------------
  GenInterruptProc2 : process
    variable IterationCount : integer := 1 ; 
  begin
    WaitForBarrier(GenerateIntSync2) ; 
    -- IntReq <= '1' after IterationCount * 10 ns + 5 ns, '0' after IterationCount * 10 ns + 50 ns ;
    wait for IterationCount * 10 ns + 5 ns ;
    Send(InterruptRecArray(1), "1") ; 
    wait for 45 ns ;
    Send(InterruptRecArray(1), "0") ; 
    
    IterationCount := IterationCount + 2 ; 
  end process GenInterruptProc2 ;

  ------------------------------------------------------------
  -- SubordinateProc
  --   Generate transactions for AxiSubordinate
  ------------------------------------------------------------
  SubordinateProc : process
    variable Addr : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0) ;
    variable Data : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) ;    
  begin

    -- Wait for outputs to propagate and signal TestDone
    WaitForClock(SubordinateRec, 2) ;
    WaitForBarrier(TestDone) ;
    wait ;
  end process SubordinateProc ;


end Interrupt3 ;

Configuration TbAb_Interrupt3 of TbAddressBusMemory is
  for TestHarness
    for TestCtrl_1 : TestCtrl
      use entity work.TestCtrl(Interrupt3) ; 
    end for ; 
--!!    for Subordinate_1 : Axi4Subordinate 
--!!      use entity OSVVM_AXI4.Axi4Memory ; 
--!!    end for ; 
  end for ; 
end TbAb_Interrupt3 ; 