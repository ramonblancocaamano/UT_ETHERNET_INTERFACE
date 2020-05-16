----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Description: Data for sending an empty UDP packet out over the MII interface.
--              "user_data" is asserted where you should replace 'nibble' with 
--              data that you wish to send.
-- 
-- The packet only requires 164 cycles to send, but a 12 bit counter_inst is used to
-- allow you to increase the packet size to 1518 (the maximum for standard
-- ethernet) if you desire.   
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY nibble_data IS
    GENERIC (
        ETH_SRC_MAC : STD_LOGIC_VECTOR(47 DOWNTO 0);
        ETH_DST_MAC : STD_LOGIC_VECTOR(47 DOWNTO 0);
        IP_SRC_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0);
        IP_DST_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0);
        UPD_SRC_PORT : STD_LOGIC_VECTOR(15 DOWNTO 0);
        UDP_DST_PORT : STD_LOGIC_VECTOR(15 DOWNTO 0);
        PAYLOAD: INTEGER;
        LOWER_BOUND : UNSIGNED(11 DOWNTO 0);
        HIGHER_BOUND : UNSIGNED(11 DOWNTO 0)
        );
    Port ( clk        : in  STD_LOGIC;
           start      : in  STD_LOGIC;
           busy       : out STD_LOGIC;
           data       : out STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
           user_data  : out STD_LOGIC                     := '0';
           data_valid : out STD_LOGIC                     := '0';
           
           --external data
           counter : out std_logic_vector (11 downto 0):=(others => '0');
           data_16b: in std_logic_vector (15 downto 0):=(others => '0'));
end nibble_data;

architecture Behavioral of nibble_data is
    constant ip_header_bytes   : integer := 20;
    constant udp_header_bytes  : integer := 8;
    constant data_bytes        : integer := 16 + PAYLOAD;
    constant ip_total_bytes    : integer := ip_header_bytes + udp_header_bytes + data_bytes;
    constant udp_total_bytes   : integer := udp_header_bytes + data_bytes;

    signal counter_inst : unsigned(11 downto 0) := (others => '0');
    signal module : unsigned(11 downto 0) := (others => '0');
    
    -- Ethernet frame header
    -- Mac addresses come from module's generic 
    signal eth_type          : std_logic_vector(15 downto 0) := x"0800";

    -- IP header
    -- IP addresses come from module's generic 
    signal ip_version        : std_logic_vector( 3 downto 0) := x"4";
    signal ip_header_len     : std_logic_vector( 3 downto 0) := x"5";
    signal ip_dscp_ecn       : std_logic_vector( 7 downto 0) := x"00";
    signal ip_identification : std_logic_vector(15 downto 0) := x"0000";     -- Checksum is optional
    signal ip_length         : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(ip_total_bytes, 16));
    signal ip_flags_and_frag : std_logic_vector(15 downto 0) := x"0000";     -- no flags48 bytes
    signal ip_ttl            : std_logic_vector( 7 downto 0)  := x"80";
    signal ip_protocol       : std_logic_vector( 7 downto 0)  := x"11";
    signal ip_checksum       : std_logic_vector(15 downto 0) := x"0000";   -- Calcuated later on
    -- for calculating the checksum 
    signal ip_checksum1     : unsigned(31 downto 0) := (others => '0');
    signal ip_checksum2     : unsigned(15 downto 0) := (others => '0');
    
    -- UDP Header
    signal udp_length        : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(udp_total_bytes, 16)); 
    signal udp_checksum      : std_logic_vector(15 downto 0) := x"0000";     -- Checksum is optional, and if presentincludes the data
begin

    counter <= std_logic_vector(counter_inst);
   ---------------------------------------------
   -- Calutate the TCP checksum using logic
   -- This should all colapse down to a constant
   -- at build-time (example #s found on the web)
   ----------------------------------------------
   --- Step 1) 4500 + 0030 + 4422 + 4000 + 8006 + 0000 + (0410 + 8A0C + FFFF + FFFF) = 0002BBCF (32-bit sum)
   ip_checksum1 <= to_unsigned(0,32) 
                 + unsigned(ip_version & ip_header_len & ip_dscp_ecn)
                 + unsigned(ip_identification)
                 + unsigned(ip_length)
                 + unsigned(ip_flags_and_frag)
                 + unsigned(ip_ttl & ip_protocol)
                 + unsigned(IP_SRC_ADDR(31 downto 16))
                 + unsigned(IP_SRC_ADDR(15 downto  0))
                 + unsigned(IP_DST_ADDR(31 downto 16))
                 + unsigned(IP_DST_ADDR(15 downto  0));
   -- Step 2) 0002 + BBCF = BBD1 = 1011101111010001 (1's complement 16-bit sum, formed by "end around carry" of 32-bit 2's complement sum)
   ip_checksum2 <= ip_checksum1(31 downto 16) + ip_checksum1(15 downto 0);
   -- Step 3) ~BBD1 = 0100010000101110 = 442E (1's complement of 1's complement 16-bit sum)
   ip_checksum  <= NOT std_logic_vector(ip_checksum2);

    module <= (counter_inst - (LOWER_BOUND + 1)) MOD 4; 
    
generate_nibbles: process (clk) 

    begin
        
        if rising_edge(clk) then
            -- Update the counter_inst of where we are 
            -- in the packet
            if counter_inst /= 0 or start = '1' then
               counter_inst <= counter_inst + 1;
            end if;
            
            -- Note, this uses the current value of counter_inst, not the one assigned above!
            data <= "0000";
            
            -- PAYLOAD.
            IF counter_inst > LOWER_BOUND AND counter_inst < HIGHER_BOUND THEN
               
                CASE module is 
                    when x"000" => data <= data_16b(11 downto 8);
                    when x"001" => data <= data_16b(15 downto 12);
                    when x"002" => data <= data_16b(3 downto 0);
                    when others => data <= data_16b(7 downto 4);
                END CASE;
            
            ELSE
            
                -- HEADER.
                case counter_inst is 
                  -- We pause at 0 count when idle (see below case statement)
                  when x"000" => NULL;
                  -----------------------------
                  -- MAC Header 
                  -----------------------------
                  -- Ethernet destination
                  when x"001" => data <= ETH_DST_MAC(43 downto 40); data_valid <= '1';
                  when x"002" => data <= ETH_DST_MAC(47 downto 44);
                  when x"003" => data <= ETH_DST_MAC(35 downto 32);
                  when x"004" => data <= ETH_DST_MAC(39 downto 36);
                  when x"005" => data <= ETH_DST_MAC(27 downto 24);
                  when x"006" => data <= ETH_DST_MAC(31 downto 28);
                  when x"007" => data <= ETH_DST_MAC(19 downto 16);
                  when x"008" => data <= ETH_DST_MAC(23 downto 20);
                  when x"009" => data <= ETH_DST_MAC(11 downto  8);
                  when x"00A" => data <= ETH_DST_MAC(15 downto 12);
                  when x"00B" => data <= ETH_DST_MAC( 3 downto  0);
                  when x"00C" => data <= ETH_DST_MAC( 7 downto  4);
                  -- Ethernet source
                  when x"00D" => data <= ETH_SRC_MAC(43 downto 40);
                  when x"00E" => data <= ETH_SRC_MAC(47 downto 44);
                  when x"00F" => data <= ETH_SRC_MAC(35 downto 32);
                  when x"010" => data <= ETH_SRC_MAC(39 downto 36);
                  when x"011" => data <= ETH_SRC_MAC(27 downto 24);
                  when x"012" => data <= ETH_SRC_MAC(31 downto 28);
                  when x"013" => data <= ETH_SRC_MAC(19 downto 16);
                  when x"014" => data <= ETH_SRC_MAC(23 downto 20);
                  when x"015" => data <= ETH_SRC_MAC(11 downto  8);
                  when x"016" => data <= ETH_SRC_MAC(15 downto 12);
                  when x"017" => data <= ETH_SRC_MAC( 3 downto  0);
                  when x"018" => data <= ETH_SRC_MAC( 7 downto  4);
                  -- Ether Type 08:00
                  when x"019" => data <= eth_type(11 downto  8);
                  when x"01A" => data <= eth_type(15 downto 12); 
                  when x"01B" => data <= eth_type( 3 downto  0);
                  when x"01C" => data <= eth_type( 7 downto  4);
                  -------------------------
                  -- User data packet
                  ------------------------------
                  -- IPv4 Header
                  ----------------------------
                  when x"01D" => data <= ip_header_len;
                  when x"01E" => data <= ip_version;
                  
                  when x"01F" => data <= ip_dscp_ecn( 3 downto  0);
                  when x"020" => data <= ip_dscp_ecn( 7 downto  4);
                  -- Length of total packet (excludes etherent header and ethernet FCS) = 0x0030
                  when x"021" => data <= ip_length(11 downto  8);
                  when x"022" => data <= ip_length(15 downto 12);
                  when x"023" => data <= ip_length( 3 downto  0);
                  when x"024" => data <= ip_length( 7 downto  4);
                  -- all zeros
                  when x"025" => data <= ip_identification(11 downto  8);
                  when x"026" => data <= ip_identification(15 downto 12);
                  when x"027" => data <= ip_identification( 3 downto  0);
                  when x"028" => data <= ip_identification( 7 downto  4);
                  -- No flags, no frament offset.
                  when x"029" => data <= ip_flags_and_frag(11 downto  8);
                  when x"02A" => data <= ip_flags_and_frag(15 downto 12);
                  when x"02B" => data <= ip_flags_and_frag( 3 downto  0);
                  when x"02C" => data <= ip_flags_and_frag( 7 downto  4);
                  -- Time to live
                  when x"02D" => data <= ip_ttl( 3 downto  0);
                  when x"02E" => data <= ip_ttl( 7 downto  4);
                  -- Protocol (UDP)
                  when x"02F" => data <= ip_protocol( 3 downto  0);
                  when x"030" => data <= ip_protocol( 7 downto  4);
                  -- Header checksum
                  when x"031" => data <= ip_checksum(11 downto  8);
                  when x"032" => data <= ip_checksum(15 downto 12);
                  when x"033" => data <= ip_checksum( 3 downto  0);
                  when x"034" => data <= ip_checksum( 7 downto  4);
                  -- source address
                  when x"035" => data <= IP_SRC_ADDR(27 downto 24);
                  when x"036" => data <= IP_SRC_ADDR(31 downto 28);
                  when x"037" => data <= IP_SRC_ADDR(19 downto 16);
                  when x"038" => data <= IP_SRC_ADDR(23 downto 20);
                  when x"039" => data <= IP_SRC_ADDR(11 downto  8);
                  when x"03A" => data <= IP_SRC_ADDR(15 downto 12);
                  when x"03B" => data <= IP_SRC_ADDR( 3 downto  0);
                  when x"03C" => data <= IP_SRC_ADDR( 7 downto  4);
                  -- dest address
                  when x"03D" => data <= IP_DST_ADDR(27 downto 24);
                  when x"03E" => data <= IP_DST_ADDR(31 downto 28);
                  when x"03F" => data <= IP_DST_ADDR(19 downto 16);
                  when x"040" => data <= IP_DST_ADDR(23 downto 20);
                  when x"041" => data <= IP_DST_ADDR(11 downto  8);
                  when x"042" => data <= IP_DST_ADDR(15 downto 12);
                  when x"043" => data <= IP_DST_ADDR( 3 downto  0);
                  when x"044" => data <= IP_DST_ADDR( 7 downto  4);
                  -- No options in this packet
                  
                  ------------------------------------------------
                  -- UDP/IP Header - from port 4096 to port 4096
                  ------------------------------------------------
                  -- Source port 4096
                  when x"045" => data <= UPD_SRC_PORT(11 downto  8);
                  when x"046" => data <= UPD_SRC_PORT(15 downto 12);
                  when x"047" => data <= UPD_SRC_PORT( 3 downto  0);
                  when x"048" => data <= UPD_SRC_PORT( 7 downto  4);
                  -- Target port 4096
                  when x"049" => data <= UDP_DST_PORT(11 downto  8);
                  when x"04A" => data <= UDP_DST_PORT(15 downto 12);
                  when x"04B" => data <= UDP_DST_PORT( 3 downto  0);
                  when x"04C" => data <= UDP_DST_PORT( 7 downto  4);
                  -- UDP Length (header + data) 24 octets
                  when x"04D" => data <= udp_length(11 downto  8);
                  when x"04E" => data <= udp_length(15 downto 12);
                  when x"04F" => data <= udp_length( 3 downto  0);
                  when x"050" => data <= udp_length( 7 downto  4);
                  -- UDP Checksum not suppled
                  when x"051" => data <= udp_checksum(11 downto  8);
                  when x"052" => data <= udp_checksum(15 downto 12);
                  when x"053" => data <= udp_checksum( 3 downto  0);
                  when x"054" => data <= udp_checksum( 7 downto  4);
                  --------------------------------------------
                  -- Finally! the  user data (defaults 
                  -- to "0000" due to assignement above CASE).
                  ---------------------------------------------
                  -- 16-bit sequence number
                  when x"055" => user_data <= '1';
                  
                  --------------------------------------------
                  -- Ethernet Frame Check Sequence (CRC) will 
                  -- be added here, overwriting these nibbles
                  --------------------------------------------
                  when x"875" => data_valid <= '0'; user_data <= '0';
                  when x"876" => NULL;
                  when x"877" => NULL;
                  when x"878" => NULL;
                  when x"879" => NULL;
                  when x"87A" => NULL;
                  when x"87B" => NULL;
                  when x"87C" => NULL;
                  ----------------------------------------------------------------------------------
                  -- End of frame - there needs to be at least 20 octets (40 counts) before  sending 
                  -- the next packet, (maybe more depending  on medium?) 12 are for the inter packet
                  -- gap, 8 allow for the preamble that will be added to the start of this packet.
                  --
                  -- Note that when the count of 0000 adds one  more nibble, so if start is assigned 
                  -- '1' this should be minimum that is  within spec.
                  ----------------------------------------------------------------------------------
                  when x"8A3" => counter_inst <= (others => '0'); busy  <= '0';
                  when others => data <= "0000";
                end case;
            END IF;
         end if;    
    end process;
end Behavioral;