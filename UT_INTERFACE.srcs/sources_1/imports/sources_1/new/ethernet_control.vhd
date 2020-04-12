----------------------------------------------------------------------------------
-- @FILE : ethernet_control.vhd 
-- @AUTHOR: BLANCO CAAMANO, RAMON. <ramonblancocaamano@gmail.com> 
-- 
-- @ABOUT: .
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY ethernet_control IS
    GENERIC( 
        DATA : INTEGER;
        PACKETS : INTEGER
    );
    PORT(
        rst : IN STD_LOGIC;
        clk: IN STD_LOGIC;   
        hsk_rd0 : IN STD_LOGIC;
        hsk_rd_ok0 : OUT STD_LOGIC;              
        hsk_wr0 : OUT STD_LOGIC;              
        hsk_wr_en0 : IN STD_LOGIC;
        buff_rd_en : OUT STD_LOGIC;   
        eth_start : OUT STD_LOGIC;
        eth_counter : IN STD_LOGIC_VECTOR(11 DOWNTO 0)  
    );
END ethernet_control;

ARCHITECTURE behavioral OF ethernet_control IS

    TYPE ST_ETH IS (IDLE, SEND);
    SIGNAL state : ST_ETH := IDLE;
    SIGNAL eth_fsm : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    
    SIGNAL ec_hsk_rd_en0 : STD_LOGIC := '0';              
    SIGNAL ec_hsk_wr0 : STD_LOGIC := '0'; 
    SIGNAL ec_buff_rd_en : STD_LOGIC := '0';  
    SIGNAL ec_eth_start : STD_LOGIC := '0';
   
BEGIN
    
    hsk_rd_ok0 <=  ec_hsk_rd_en0;              
    hsk_wr0 <= ec_hsk_wr0; 
    buff_rd_en <= ec_buff_rd_en;  
    eth_start <= ec_eth_start;
    
    
    PROCESS(rst, clk, hsk_rd0, hsk_wr_en0, eth_counter,
        state, ec_hsk_rd_en0, ec_hsk_wr0, ec_buff_rd_en, ec_eth_start)
    
        VARIABLE counter : INTEGER := 0;
        VARIABLE counter_packets : INTEGER := 0;
    
    BEGIN
        IF rst = '1' THEN
            state <= IDLE;
            counter := 0;
            counter_packets := 0;
            ec_hsk_rd_en0 <= '0';
            ec_hsk_wr0 <= '0';
            ec_buff_rd_en <= '0';
            ec_eth_start <= '0';                    
        ELSIF RISING_EDGE(clk) THEN           
            CASE (state) IS
            
                WHEN IDLE =>
                
                    counter := 0; 
                    ec_buff_rd_en <= '0';
                    ec_eth_start <= '0';                                           
                    IF counter_packets = PACKETS THEN
                        counter_packets := 0;
                    END IF;                        
                    IF hsk_wr_en0 = '1' THEN
                        ec_hsk_wr0 <= '0';
                    END IF;                        
                    IF hsk_rd0 = '1' THEN                            
                        ec_hsk_rd_en0 <= '1';
                        state <= SEND;
                    END IF;
                
                WHEN SEND =>
                
                    IF hsk_rd0 = '0' THEN
                        ec_hsk_rd_en0 <= '0';
                    END IF;                            
                    IF counter < DATA THEN
                        IF eth_counter = x"000" THEN
                            IF ec_eth_start = '0' THEN
                                counter := counter + 1; 
                                ec_buff_rd_en <= '1';
                                ec_eth_start <= '1';  
                            ELSE 
                                ec_buff_rd_en <= '0';
                            END IF;
                        ELSE
                            ec_eth_start <= '0';
                        END IF;                       
                    ELSE
                        ec_buff_rd_en <= '0';
                        IF eth_counter /= x"000" THEN
                            state <= IDLE;
                            counter_packets := counter_packets + 1; 
                            ec_eth_start <= '0';                        
                            IF counter_packets < PACKETS - 1 THEN
                                ec_hsk_wr0 <= '1';
                            END IF; 
                        END IF;
                    END IF;
                        
                END CASE;
            END IF;
        END PROCESS;
        
        STATE_ETH: BLOCK
        BEGIN
            WITH state SELECT eth_fsm <=
                x"00" WHEN IDLE,
                x"01" WHEN SEND,	
                x"FF" WHEN OTHERS
             ;
        END BLOCK STATE_ETH;

END behavioral;