--
--  File Name:         InterruptHandler.vhd
--  Design Unit Name:  InterruptHandler
--  Revision:          OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      InterruptHandler
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    04/2021   2021.04    Initial revision
--
--
--  This file is part of OSVVM.
--
--  Copyright (c) 2017 - 2021 by SynthWorks Design Inc.
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
library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use ieee.numeric_std_unsigned.all ;
  use ieee.math_real.all ;

library osvvm ;
  context osvvm.OsvvmContext ;

  use work.AddressBusTransactionPkg.all; 


entity InterruptHandler is
port (
  -- Interrupt Input
  IntReq          : in   std_logic ;

  -- From TestCtrl
  TransRec        : inout AddressBusRecType ;
  InterruptRec    : inout AddressBusRecType ;
  
  -- To Verification Component
  VCRec           : inout AddressBusRecType
) ;
end entity InterruptHandler ;
architecture Behavioral of InterruptHandler is
  constant POLARITY : std_logic := '1' ;
  signal   iIntReq  : std_logic := '0' ;
begin

  -- Only handle interrupts when interrupt transactions pending 
  iIntReq   <= TO_X01(IntReq) when TransactionPending(InterruptRec.Rdy, InterruptRec.Ack) 
               else '0' ;

  TransactionSelection : process 
    variable IntState : boolean := FALSE ;
  begin
    FinishTransaction(TransRec.Ack) ;       -- due to differences in handling
    FinishTransaction(InterruptRec.Ack) ;   -- due to differences in handling
    loop
      if not IntState then 
        if not(TransactionPending(TransRec.Rdy, TransRec.Ack) or iIntReq = '1') then 
          wait until TransactionPending(TransRec.Rdy, TransRec.Ack) or iIntReq = '1' ;
        end if ; 
        if iIntReq = '1' then 
          IntState := TRUE ; 
        else
          -- Copy normal transaction info to VCRec
          VCRec.Operation       <=  TransRec.Operation   ;
          VCRec.Address         <=  TransRec.Address     ;
          VCRec.AddrWidth       <=  TransRec.AddrWidth   ;
          VCRec.DataToModel     <=  TransRec.DataToModel ;
          VCRec.DataWidth       <=  TransRec.DataWidth   ;
          VCRec.WriteBurstFifo  <=  TransRec.WriteBurstFifo ; 
          VCRec.ReadBurstFifo   <=  TransRec.ReadBurstFifo ; 
          VCRec.StatusMsgOn     <=  TransRec.StatusMsgOn ;
          VCRec.IntToModel      <=  TransRec.IntToModel  ;
          VCRec.BoolToModel     <=  TransRec.BoolToModel ;
          VCRec.Options         <=  TransRec.Options     ;
          
          -- Forward transaction to VC
          RequestTransaction(Rdy => VCRec.Rdy, Ack => VCRec.Ack) ; 

          -- Copy transaction results back to TransRec
          TransRec.DataFromModel <= VCRec.DataFromModel ;
          TransRec.IntFromModel  <= VCRec.IntFromModel  ;
          TransRec.BoolFromModel <= VCRec.BoolFromModel ;
          
          -- Complete Transaction on TransRec side
          FinishTransaction(TransRec.Ack) ; 
        end if ; 
      end if ; 
      
      if IntState then 
        if not(TransactionPending(InterruptRec.Rdy, InterruptRec.Ack)) then 
          wait until TransactionPending(InterruptRec.Rdy, InterruptRec.Ack) ;
        end if ; 
        if InterruptRec.Operation = INTERRUPT_RETURN then 
          IntState := FALSE ; 
        else
          -- Copy interrupt transaction info to VCRec
          VCRec.Operation       <=  InterruptRec.Operation   ;
          VCRec.Address         <=  InterruptRec.Address     ;
          VCRec.AddrWidth       <=  InterruptRec.AddrWidth   ;
          VCRec.DataToModel     <=  InterruptRec.DataToModel ;
          VCRec.DataWidth       <=  InterruptRec.DataWidth   ;
          VCRec.WriteBurstFifo  <=  InterruptRec.WriteBurstFifo ; 
          VCRec.ReadBurstFifo   <=  InterruptRec.ReadBurstFifo ; 
          VCRec.StatusMsgOn     <=  InterruptRec.StatusMsgOn ;
          VCRec.IntToModel      <=  InterruptRec.IntToModel  ;
          VCRec.BoolToModel     <=  InterruptRec.BoolToModel ;
          VCRec.Options         <=  InterruptRec.Options     ;
          
          -- Forward transaction to VC
          RequestTransaction(Rdy => VCRec.Rdy, Ack => VCRec.Ack) ; 

          -- Copy transaction results back to InterruptRec
          InterruptRec.DataFromModel <= VCRec.DataFromModel ;
          InterruptRec.IntFromModel  <= VCRec.IntFromModel  ;
          InterruptRec.BoolFromModel <= VCRec.BoolFromModel ;
        end if ; 
        
        -- Complete Transaction on TransRec side
        FinishTransaction(TransRec.Ack) ; 
      end if ; 
    end loop ; 
  end process TransactionSelection ;  

end architecture Behavioral ; 