----------------------------------------------------------------------------------
-- @FILE : interface.vhd 
-- @AUTHOR: BLANCO CAAMANO, RAMON. <ramonblancocaamano@gmail.com> 
-- 
-- @ABOUT: MANAGEMENT OF ETHERNET INTERFACE.
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY interface IS
    GENERIC( 
        DATA : INTEGER := 4;
        PACKETS : INTEGER := 8;
        ETH_SRC_MAC : STD_LOGIC_VECTOR(47 DOWNTO 0) := x"DEADBEEF0123";
        ETH_DST_MAC : STD_LOGIC_VECTOR(47 DOWNTO 0) := x"000EC6E1F958";
        IP_SRC_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"0A0A0A0A";
        IP_DST_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"C0A8010B"
    );
    PORT(
        rst : IN STD_LOGIC;
        clk: IN STD_LOGIC;                
        din: IN STD_LOGIC_VECTOR(15 DOWNTO 0);         
        hsk_rd0 : IN STD_LOGIC;
        hsk_rd_ok0 : OUT STD_LOGIC;              
        hsk_wr0 : OUT STD_LOGIC;              
        hsk_wr_en0 : IN STD_LOGIC;    
        buff_rd_en : OUT STD_LOGIC;   
        i_eth_tx_clk : IN  STD_LOGIC;  
        o_eth_rstn : OUT   STD_LOGIC;
        o_eth_tx_d : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        o_eth_tx_en : OUT STD_LOGIC;            
        o_eth_ref_clk : OUT STD_LOGIC
    );  
END interface;

ARCHITECTURE behavioral OF interface IS

    COMPONENT ethernet
        GENERIC( 
            ETH_SRC_MAC : STD_LOGIC_VECTOR(47 DOWNTO 0);
            ETH_DST_MAC : STD_LOGIC_VECTOR(47 DOWNTO 0);
            IP_SRC_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0);
            IP_DST_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
        PORT( 
            clock : IN STD_LOGIC; 
            data_16b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);      
            eth_rstn : OUT STD_LOGIC := '1';
            eth_tx_d : OUT STD_LOGIC_VECTOR := (OTHERS => '0');
            eth_tx_en : OUT STD_LOGIC := '0';
            eth_tx_clk  : IN  STD_LOGIC;        
            eth_ref_clk : OUT STD_LOGIC;
            start: IN STD_LOGIC;
            counter : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)                              
           );
    END COMPONENT;
    
    COMPONENT ethernet_control 
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
    END COMPONENT;
    
    SIGNAL eth_start : STD_LOGIC := '0';
    SIGNAL eth_counter : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');  

BEGIN

    INST_ETHERNET : ethernet
        GENERIC MAP( 
            ETH_SRC_MAC => ETH_SRC_MAC,
            ETH_DST_MAC => ETH_DST_MAC,
            IP_SRC_ADDR => IP_SRC_ADDR,
            IP_DST_ADDR => IP_DST_ADDR
        )
        PORT MAP(
            clock => clk,
            data_16b => din,
            eth_rstn => o_eth_rstn,
            eth_tx_d => o_eth_tx_d,
            eth_tx_en => o_eth_tx_en,
            eth_tx_clk => i_eth_tx_clk,
            eth_ref_clk => o_eth_ref_clk,
            start => eth_start,
            counter => eth_counter
        );
        
    INST_ETHERNET_CONTROL : ethernet_control
        GENERIC MAP( 
            DATA => DATA,
            PACKETS => PACKETS
        ) 
        PORT MAP(
            rst => rst,
            clk => i_eth_tx_clk,                            
            hsk_rd0 => hsk_rd0,
            hsk_rd_ok0 => hsk_rd_ok0,             
            hsk_wr0 => hsk_wr0,              
            hsk_wr_en0 => hsk_wr_en0,
            buff_rd_en => buff_rd_en,   
            eth_start => eth_start,
            eth_counter => eth_counter
        );

END behavioral;
