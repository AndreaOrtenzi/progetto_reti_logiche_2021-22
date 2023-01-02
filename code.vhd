----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.01.2022 12:28:09
-- Design Name: 
-- Module Name: project_reti_logiche - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_start : in STD_LOGIC;
           i_data : in STD_LOGIC_VECTOR(7 downto 0);
           o_address : out STD_LOGIC_VECTOR(15 downto 0);
           o_done : out STD_LOGIC;
           o_en : out STD_LOGIC;
           o_we : out STD_LOGIC;
           o_data : out STD_LOGIC_VECTOR(7 downto 0)           
    );
end project_reti_logiche;

architecture readWrite of project_reti_logiche is 
	--PR:Process and read WP: Write and process (Process=Encode and Read= asking the memory an address)
	type state_type is (S_IDLE, S_readByte1,PR,WP, S_finish,W1,W2,W3,R);
	signal current_state: state_type := S_IDLE;
	
	--this is the state of the convolutional encoder 
	signal stateConv : std_logic_vector(1 downto 0):="00";
	
	signal lastAddressToRead : unsigned(7 downto 0) := (OTHERS => '0');	
	signal byteToWrite1,byteToWrite2,byteToWrite3 : std_logic_vector(7 downto 0);
	signal pipelinedIstrFinished: boolean:=false;
	
	--largest number is 255 but 
	--I need 9bits because I need to check if readAddress>lastAddressToRead and with 7 bits I'll have overflow coming back to 0 after 255
	signal readAddress : unsigned(8 downto 0):=(OTHERS => '0');
	--largest number is 1510=1000+255*2
	signal writeAddress : unsigned(10 downto 0):= "01111101000";	
	
begin
	
	lambda: process(i_clk)			
			
    begin
        if i_clk'event and i_clk = '0' then
            if i_rst = '1' then
                current_state <= S_IDLE;
            else
                case current_state is
                    when S_IDLE =>
                        
                        pipelinedIstrFinished <= false;
                        writeAddress <= "01111101000"; --in decimal 1000
                        readAddress <= (OTHERS => '0');
                        o_done <= '0';
                        o_address <= (OTHERS => '0');
                        stateConv <= "00";
                        lastAddressToRead <= (OTHERS => '0');
                        
                        if i_start='1' then            
                            current_state <= S_readByte1;
                            o_en<='1';
                            o_we<='0';
                            --readAddress <= readAddress + 1; this way doesn't work with reset because readAddress will be old value + 1
                            readAddress <= "000000001";
                        else
                            current_state <= S_IDLE;
                        end if;
                        
                    when S_readByte1 =>
                        --I know that I can use the fist byte because the addresses that I've to read start at 1 and then increase.
                        lastAddressToRead <= unsigned(i_data);
                         
                        if "00000000" = i_data then
                            --0 byte to read, go to finish
                            current_state <= S_finish;
                        else
                            current_state <= PR;
                            --ask for the second byte now to have it next clk cycle
                            o_address <= "0000000" & std_logic_vector(readAddress);
                            o_en<='1';
                            o_we<='0';
                            readAddress <= readAddress + 1;
                        end if;
                    when R =>
                                                    
                        --ask for the second byte now to have it next clk cycle
                        o_address <= "0000000" & std_logic_vector(readAddress);
                        o_en<='1';
                        o_we<='0';
                        readAddress <= readAddress + 1;
                        
                        current_state <= PR;                            

                    when PR =>
                        current_state <= WP;
                        
                        if  readAddress <= lastAddressToRead then
                            o_address <= "0000000" & std_logic_vector(readAddress);
                            o_en<='1';
                            o_we<='0';
                            readAddress <= readAddress + 1;
                        else 
                            pipelinedIstrFinished <= true;
                                             
                        end if;
                        
                        --encoding part:                                                
                        --process first 4bits and put them in o_data ready to be written
                        o_data(7)<= i_data(7) xor stateConv(0);
                        o_data(6)<= i_data(7) xor stateConv(0) xor stateConv(1);                        
                        o_data(5)<= i_data(6) xor stateConv(1);
                        o_data(4)<= i_data(6) xor i_data(7) xor stateConv(1);                        
                        o_data(3)<= i_data(5) xor i_data(7);
                        o_data(2)<= i_data(5) xor i_data(7) xor i_data(6);                        
                        o_data(1)<= i_data(4) xor i_data(6);
                        o_data(0)<= i_data(4) xor i_data(6) xor i_data(5);                        

                        --process remaining bits
                        byteToWrite1(7)<= i_data(3) xor i_data(5);
                        byteToWrite1(6)<= i_data(3) xor i_data(5) xor i_data(4);                        
                        byteToWrite1(5)<= i_data(2) xor i_data(4);
                        byteToWrite1(4)<= i_data(2) xor i_data(4) xor i_data(3);                        
                        byteToWrite1(3)<= i_data(1) xor i_data(3);
                        byteToWrite1(2)<= i_data(1) xor i_data(3) xor i_data(2);                        
                        byteToWrite1(1)<= i_data(0) xor i_data(2);
                        byteToWrite1(0)<= i_data(0) xor i_data(2) xor i_data(1);                        
                        
                        --the encoder's state is computed with a sort of shift register so i can set it with the last 2 bits of i_data
                        stateConv <= i_data(0) & i_data(1);
                        
                    when WP =>
                        current_state <= W1;
                        
                        --writing part
                        o_address <= "00000" & std_logic_vector(writeAddress);
                        o_en<='1';
                        o_we<='1';
                        
                        writeAddress <= writeAddress + 1;
                        
                        --processing pipelined istr:
                        
                        if not pipelinedIstrFinished then
                            --process first 4bits and put them in o_data ready to be written
                            byteToWrite2(7)<= i_data(7) xor stateConv(0);
                            byteToWrite2(6)<= i_data(7) xor stateConv(0) xor stateConv(1);                        
                            byteToWrite2(5)<= i_data(6) xor stateConv(1);
                            byteToWrite2(4)<= i_data(6) xor i_data(7) xor stateConv(1);                        
                            byteToWrite2(3)<= i_data(5) xor i_data(7);
                            byteToWrite2(2)<= i_data(5) xor i_data(7) xor i_data(6);                        
                            byteToWrite2(1)<= i_data(4) xor i_data(6);
                            byteToWrite2(0)<= i_data(4) xor i_data(6) xor i_data(5);
    
                            --process remaining bits
                            byteToWrite3(7)<= i_data(3) xor i_data(5);
                            byteToWrite3(6)<= i_data(3) xor i_data(5) xor i_data(4);                        
                            byteToWrite3(5)<= i_data(2) xor i_data(4);
                            byteToWrite3(4)<= i_data(2) xor i_data(4) xor i_data(3);                        
                            byteToWrite3(3)<= i_data(1) xor i_data(3);
                            byteToWrite3(2)<= i_data(1) xor i_data(3) xor i_data(2);                        
                            byteToWrite3(1)<= i_data(0) xor i_data(2);
                            byteToWrite3(0)<= i_data(0) xor i_data(2) xor i_data(1);
                            
                            stateConv <= i_data(0) & i_data(1);
                        end if;
                    
                    when W1 =>
                        if pipelinedIstrFinished then
                            current_state <= S_finish;
                        else
                            current_state <= W2;
                        end if;
                        
                        --writing part
                        o_data <= byteToWrite1;
                        o_address <= "00000" & std_logic_vector(writeAddress);
                        o_en<='1';
                        o_we<='1';
                        
                        writeAddress <= writeAddress + 1;
                        
                    when W2 =>
                    
                        o_address <= "00000" & std_logic_vector(writeAddress);
                        o_en<='1';
                        o_we<='1';
                        o_data <= byteToWrite2;
                        
                        writeAddress <= writeAddress + 1;
                        
                        current_state <= W3;
                        
                    when W3 =>
                        --writing part
                        o_address <= "00000" & std_logic_vector(writeAddress);
                        o_en<='1';
                        o_we<='1';
                        o_data <= byteToWrite3;
                        
                        writeAddress <= writeAddress + 1;
                        
                        
                        if  readAddress <= lastAddressToRead then                         
                            current_state <= R;                           
                        else
                            current_state <= S_finish; 
                        end if;

                                            
                    when S_finish =>
                    
                        o_en <= '0';
                        o_we <= '0';
                        o_done <= '1';
                        
                        if i_start='0' then
                            --come back to S_IDLE to be ready for other byte streams
                            current_state <= S_IDLE;
                        else
                            --wait here until the RAM will understand that it finished 
                            current_state <= S_finish;
                        end if;
                end case;
            end if;
        end if;
    end process;
end readWrite;

--serial version
--architecture readWrite of project_reti_logiche is 
--	type state_type is (S_IDLE, S_askByte1,S_loadByte,S_writeByte, S_finish,S_askByteN,S00,S01,S10,S11);
--	signal current_state: state_type := S_IDLE;
--	signal lastStateConv : state_type := S00;
--	signal byteRead,byteToWrite : std_logic_vector(7 downto 0);
--	signal numVal,countReadBytes : unsigned(7 downto 0) := "00000000";
--	signal bitNumber : natural := 7;	
	
--begin
	
--	lambda: process(i_clk)			
--			variable writeAddress, readAddress : unsigned(15 downto 0);
--			variable lessSignBitNumber : natural := 6;
--    begin
--        if i_clk'event and i_clk = '0' then
--            if i_rst = '1' then
--                current_state <= S_IDLE;
--            else
--                case current_state is
--                    when S_IDLE =>
--                        countReadBytes <= (OTHERS => '0');
--                        numVal <= (OTHERS => '0');
--                        writeAddress := "0000001111101000"; --in decimal 1000
--                        readAddress := (OTHERS => '0');
--                        o_done <= '0';
--                        o_address <= (OTHERS => '0');
--                        lastStateConv <= S00;
                        
--                        if i_start='1' then            
--                            current_state <= S_askByte1;
--                            o_en<='1';
--                            o_we<='0';
--                        else
--                            current_state <= S_IDLE;
--                        end if;
                        
--                    when S_askByte1 =>
                        
--                        numVal <= unsigned(i_data);
--                        readAddress := readAddress + 1;                       
                        
--                        bitNumber <= 7;
                         
--                        if countReadBytes = unsigned(i_data) then
--                            --0 byte to read, go to finish
--                            current_state <= S_finish;
--                        else
--                            current_state <= S_loadByte;
--                            --ask for the second byte now to have it next clk cycle
--                            o_address <= std_logic_vector(readAddress);
--                            o_en<='1';
--                            o_we<='0'; 
--                        end if;
                        
                        
--                    when S_loadByte =>
--                        byteRead <= i_data;
--                        readAddress := readAddress + 1;
--                        countReadBytes <= countReadBytes + 1;
--                        current_state <= lastStateConv;
                        
--                        lessSignBitNumber := 6;
                        
--                        byteToWrite <= (OTHERS => '0');
                        
--                    when S00 =>
--                        --all the states named SXX are similar, they are the core of the convolutional encoder
--                        --I comment only this state
                        
--                        if bitNumber>0 then
--                            --to avoid underflow
--                            bitNumber <= bitNumber - 1;
--                        end if;
            
--                        if bitNumber > 3 then
--                            --lessSignBitNumber is the index of byteToWrite, I need these two formulas because it generates 2B from 1B
--                            lessSignBitNumber := (bitNumber-4)*2;
--                        else
--                            if bitNumber = 3 then
--                                writeAddress := writeAddress + 1;
--                            end if;
--                            lessSignBitNumber := (bitNumber)*2;
--                        end if;
            
--                        if bitNumber = 0 or bitNumber = 4 then
--                            --after 4 bits of byteRead byteToWrite is ready so write it to the RAM
--                            current_state <= S_writeByte;
                            
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                --save the state that It's leaving to pick up where he left off, 
--                                --reset the the state of the encoder only when the entire stream of bytes is processed (in S_IDLE)
--                                lastStateConv <= S00;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                lastStateConv <= S10;
--                            end if;
--                        else
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                current_state <= S00;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                current_state <= S10;
--                            end if;
--                        end if;
                        
--                        o_en<='0';
--                        o_we<='0';
                    
--                    when S01 =>
--                        if bitNumber>0 then
--                            bitNumber <= bitNumber - 1;
--                        end if;
                    
--                        if bitNumber > 3 then
--                            lessSignBitNumber := (bitNumber-4)*2;
--                        else
--                            if bitNumber = 3 then
--                                writeAddress := writeAddress + 1;
--                            end if;
--                            lessSignBitNumber := (bitNumber)*2;
--                        end if;
            
--                        if bitNumber = 0 or bitNumber = 4 then
                            
--                            current_state <= S_writeByte;
                            
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                lastStateConv <= S00;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                lastStateConv <= S10;
--                            end if;
--                        else
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                current_state <= S00;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                current_state <= S10;
--                            end if;
--                        end if;
                        
--                        o_en<='0';
--                        o_we<='0';
                        
--                    when S10 =>
--                        if bitNumber>0 then
--                            bitNumber <= bitNumber - 1;
--                        end if;
                                
--                        if bitNumber > 3 then
--                            lessSignBitNumber := (bitNumber-4)*2;
--                        else
--                            if bitNumber = 3 then
--                                writeAddress := writeAddress + 1;
--                            end if;
--                            lessSignBitNumber := (bitNumber)*2;
--                        end if;
            
--                        if bitNumber = 0 or bitNumber = 4 then
                            
--                            current_state <= S_writeByte;
                            
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                lastStateConv <= S01;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                lastStateConv <= S11;
--                            end if;
--                        else
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                current_state <= S01;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                current_state <= S11;
--                            end if;
--                        end if;
                        
--                        o_en<='0';
--                        o_we<='0';
                        
--                    when S11 =>
--                        if bitNumber>0 then
--                            bitNumber <= bitNumber - 1;
--                        end if;
                                            
--                        if bitNumber > 3 then
--                            lessSignBitNumber := (bitNumber-4)*2;
--                        else
--                            if bitNumber = 3 then
--                                writeAddress := writeAddress + 1;
--                            end if;
--                            lessSignBitNumber := (bitNumber)*2;
--                        end if;
            
--                        if bitNumber = 0 or bitNumber = 4 then
                            
--                            current_state <= S_writeByte;
                            
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                lastStateConv <= S01;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                lastStateConv <= S11;
--                            end if;
--                        else
--                            if byteRead(bitNumber) = '0' then
--                                byteToWrite(lessSignBitNumber+1) <= '1';
--                                byteToWrite(lessSignBitNumber) <= '0';
--                                current_state <= S01;
--                            else
--                                byteToWrite(lessSignBitNumber+1) <= '0';
--                                byteToWrite(lessSignBitNumber) <= '1';
--                                current_state <= S11;
--                            end if;
--                        end if;
                        
--                        o_en<='0';
--                        o_we<='0';
                        
--                    when S_writeByte =>
                        
--                        o_address <= std_logic_vector(writeAddress);
--                        o_en<='1';
--                        o_we<='1';
--                        o_data <= byteToWrite;
                        
--                        if bitNumber = 0 then                    
--                            --byteRead is completely processed
--                            current_state <= S_askByteN;
--                        else
--                            --process the second half of byteRead 
--                            current_state <= lastStateConv;
--                        end if;
                        
--                    when S_askByteN =>
                        
--                        writeAddress := writeAddress + 1;
--                        bitNumber <= 7;
                        
--                        if countReadBytes = numVal then
--                            --0 remaining bytes to read, go to finish
--                            current_state <= S_finish;
--                        else
--                            --ask for the next byte of the stream now to have it in the next clk cycle
--                            o_address <= std_logic_vector(readAddress);
--                            o_en<='1';
--                            o_we<='0';
                            
--                            current_state <= S_loadByte;
--                        end if;
                                            
--                    when S_finish =>
                    
--                        o_en <= '0';
--                        o_we <= '0';
--                        o_done <= '1';
                        
--                        if i_start='0' then
--                            --come back to S_IDLE to be ready for other byte streams
--                            current_state <= S_IDLE;
--                        else
--                            --wait here until the RAM will understand that it finished 
--                            current_state <= S_finish;
--                        end if;
--                end case;
--            end if;
--        end if;
--    end process;
--end readWrite;



