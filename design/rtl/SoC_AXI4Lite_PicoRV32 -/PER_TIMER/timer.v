//-----------------------------------------------------------------
//                        RISC-V Test SoC
//                            V0.1
//                     Ultra-Embedded.com
//                     Copyright 2014-2019
//
//                   admin@ultra-embedded.com
//
//                       License: BSD
//-----------------------------------------------------------------

//-----------------------------------------------------------------
//                          Generated File
//-----------------------------------------------------------------

`include "timer_defs.v"

//-----------------------------------------------------------------
// Module:  System Tick Timer
//-----------------------------------------------------------------
module timer
(
    // Inputs
     input          clk_i
    ,input          rst_i
    ,input          cfg_awvalid_i
    ,input  [31:0]  cfg_awaddr_i
    ,input          cfg_wvalid_i
    ,input  [31:0]  cfg_wdata_i
    ,input  [3:0]   cfg_wstrb_i
    ,input          cfg_bready_i
    ,input          cfg_arvalid_i
    ,input  [31:0]  cfg_araddr_i
    ,input          cfg_rready_i

    // Outputs
    ,output         cfg_awready_o
    ,output         cfg_wready_o
    ,output         cfg_bvalid_o
    ,output [1:0]   cfg_bresp_o
    ,output         cfg_arready_o
    ,output         cfg_rvalid_o
    ,output [31:0]  cfg_rdata_o
    ,output [1:0]   cfg_rresp_o
    ,output         intr_o
);

// ================================================================
//  NOVOS REGISTRADORES (Timer0): PRESCALER + POSTSCALER + STATUS
//  Para funcionar, adicione estes defines no timer_defs.v:
//
//   `define TIMER_PRESCALE0   8'h20   // [15:0] DIV (0=>1)
//   `define TIMER_POSTSCALE0  8'h24   // [7:0]  DIV (0=>1)
//   `define TIMER_STATUS0     8'h28   // bit0 MATCH_PEND (W1C), bit1 IRQ_PEND (W1C)
//
// ================================================================


//-----------------------------------------------------------------
// Retime write data
//-----------------------------------------------------------------
reg [31:0] wr_data_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    wr_data_q <= 32'b0;
else
    wr_data_q <= cfg_wdata_i;

//-----------------------------------------------------------------
// Request Logic
//-----------------------------------------------------------------
wire read_en_w  = cfg_arvalid_i & cfg_arready_o;
wire write_en_w = cfg_awvalid_i & cfg_awready_o;

//-----------------------------------------------------------------
// Accept Logic
//-----------------------------------------------------------------
assign cfg_arready_o = ~cfg_rvalid_o;
assign cfg_awready_o = ~cfg_bvalid_o && ~cfg_arvalid_i;
assign cfg_wready_o  = cfg_awready_o;


//-----------------------------------------------------------------
// Register timer_ctrl0
//-----------------------------------------------------------------
reg timer_ctrl0_wr_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_ctrl0_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_CTRL0))
    timer_ctrl0_wr_q <= 1'b1;
else
    timer_ctrl0_wr_q <= 1'b0;

// timer_ctrl0_interrupt [internal]
reg        timer_ctrl0_interrupt_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_ctrl0_interrupt_q <= 1'd`TIMER_CTRL0_INTERRUPT_DEFAULT;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_CTRL0))
    timer_ctrl0_interrupt_q <= cfg_wdata_i[`TIMER_CTRL0_INTERRUPT_R];

wire        timer_ctrl0_interrupt_out_w = timer_ctrl0_interrupt_q;


// timer_ctrl0_enable [internal]
reg        timer_ctrl0_enable_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_ctrl0_enable_q <= 1'd`TIMER_CTRL0_ENABLE_DEFAULT;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_CTRL0))
    timer_ctrl0_enable_q <= cfg_wdata_i[`TIMER_CTRL0_ENABLE_R];

wire        timer_ctrl0_enable_out_w = timer_ctrl0_enable_q;

// timer_ctrl0_autoreload [internal]  (NEW)
reg timer_ctrl0_autoreload_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_ctrl0_autoreload_q <= 1'd`TIMER_CTRL0_AUTORELOAD_DEFAULT;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_CTRL0))
    timer_ctrl0_autoreload_q <= cfg_wdata_i[`TIMER_CTRL0_AUTORELOAD_R];

wire timer_ctrl0_autoreload_out_w = timer_ctrl0_autoreload_q;

//-----------------------------------------------------------------
// Register timer_cmp0
//-----------------------------------------------------------------
reg timer_cmp0_wr_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_cmp0_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_CMP0))
    timer_cmp0_wr_q <= 1'b1;
else
    timer_cmp0_wr_q <= 1'b0;

// timer_cmp0_value [internal]
reg [31:0]  timer_cmp0_value_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_cmp0_value_q <= 32'd`TIMER_CMP0_VALUE_DEFAULT;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_CMP0))
    timer_cmp0_value_q <= cfg_wdata_i[`TIMER_CMP0_VALUE_R];

wire [31:0]  timer_cmp0_value_out_w = timer_cmp0_value_q;


//-----------------------------------------------------------------
// Register timer_val0
//-----------------------------------------------------------------
reg timer_val0_wr_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_val0_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_VAL0))
    timer_val0_wr_q <= 1'b1;
else
    timer_val0_wr_q <= 1'b0;

// timer_val0_current [external]
wire [31:0]  timer_val0_current_out_w = wr_data_q[`TIMER_VAL0_CURRENT_R];


//-----------------------------------------------------------------
// Timer0 - Prescaler register (NEW)
//-----------------------------------------------------------------
reg timer_prescale0_wr_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_prescale0_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_PRESCALE0))
    timer_prescale0_wr_q <= 1'b1;
else
    timer_prescale0_wr_q <= 1'b0;

reg [15:0] timer_prescale0_div_q; // N (>=1), 0 tratado como 1
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_prescale0_div_q <= 16'd1;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_PRESCALE0))
    timer_prescale0_div_q <= cfg_wdata_i[15:0];

wire [15:0] timer_prescale0_div_eff_w = (timer_prescale0_div_q == 16'd0) ? 16'd1 : timer_prescale0_div_q;


//-----------------------------------------------------------------
// Timer0 - Postscaler register (NEW)
//-----------------------------------------------------------------
reg timer_postscale0_wr_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_postscale0_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_POSTSCALE0))
    timer_postscale0_wr_q <= 1'b1;
else
    timer_postscale0_wr_q <= 1'b0;

reg [7:0] timer_postscale0_div_q; // M (>=1), 0 tratado como 1
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_postscale0_div_q <= 8'd1;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_POSTSCALE0))
    timer_postscale0_div_q <= cfg_wdata_i[7:0];

wire [7:0] timer_postscale0_div_eff_w = (timer_postscale0_div_q == 8'd0) ? 8'd1 : timer_postscale0_div_q;


//-----------------------------------------------------------------
// Timer0 - Status register (NEW)  (sticky + W1C)
// bit0: MATCH_PEND  (set on match_pulse)
// bit1: IRQ_PEND    (set when postscaler expires and IRQ enabled)
//-----------------------------------------------------------------
reg timer_status0_wr_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    timer_status0_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_STATUS0))
    timer_status0_wr_q <= 1'b1;
else
    timer_status0_wr_q <= 1'b0;

reg timer0_match_pend_q;
reg timer0_irq_pend_q;

wire [31:0]  timer_val0_current_in_w;


//-----------------------------------------------------------------
// Read mux
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ *
begin
    data_r = 32'b0;

    case (cfg_araddr_i[7:0])

    `TIMER_CTRL0:
    begin
        data_r[`TIMER_CTRL0_INTERRUPT_R] = timer_ctrl0_interrupt_q;
        data_r[`TIMER_CTRL0_ENABLE_R]    = timer_ctrl0_enable_q;
        data_r[`TIMER_CTRL0_AUTORELOAD_R] = timer_ctrl0_autoreload_q; //new
    end
    `TIMER_CMP0:
    begin
        data_r[`TIMER_CMP0_VALUE_R] = timer_cmp0_value_q;
    end
    `TIMER_VAL0:
    begin
        data_r[`TIMER_VAL0_CURRENT_R] = timer_val0_current_in_w;
    end

    // NEW: Prescaler / Postscaler / Status
    `TIMER_PRESCALE0:
    begin
        data_r[15:0] = timer_prescale0_div_q;
    end
    `TIMER_POSTSCALE0:
    begin
        data_r[7:0] = timer_postscale0_div_q;
    end
    `TIMER_STATUS0:
    begin
        data_r[0] = timer0_match_pend_q;
        data_r[1] = timer0_irq_pend_q;
    end

    default :
        data_r = 32'b0;
    endcase
end

//-----------------------------------------------------------------
// RVALID
//-----------------------------------------------------------------
reg rvalid_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    rvalid_q <= 1'b0;
else if (read_en_w)
    rvalid_q <= 1'b1;
else if (cfg_rready_i)
    rvalid_q <= 1'b0;

assign cfg_rvalid_o = rvalid_q;

//-----------------------------------------------------------------
// Retime read response
//-----------------------------------------------------------------
reg [31:0] rd_data_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    rd_data_q <= 32'b0;
else if (!cfg_rvalid_o || cfg_rready_i)
    rd_data_q <= data_r;

assign cfg_rdata_o = rd_data_q;
assign cfg_rresp_o = 2'b0;

//-----------------------------------------------------------------
// BVALID
//-----------------------------------------------------------------
reg bvalid_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    bvalid_q <= 1'b0;
else if (write_en_w)
    bvalid_q <= 1'b1;
else if (cfg_bready_i)
    bvalid_q <= 1'b0;

assign cfg_bvalid_o = bvalid_q;
assign cfg_bresp_o  = 2'b0;


wire timer_val0_wr_req_w = timer_val0_wr_q;

//-----------------------------------------------------------------
// Timer0 (com Prescaler + Postscaler)
//-----------------------------------------------------------------
reg [31:0] timer0_value_q;

// prescaler counter (conta clocks até gerar um "tick" do timer)
reg [15:0] timer0_presc_cnt_q;

// postscaler counter (conta eventos de match até gerar IRQ pendente)
reg [7:0]  timer0_post_cnt_q;

// detecção de borda do match para não contar múltiplos ciclos no mesmo valor
reg match0_d_q;
wire match0_now_w   = (timer0_value_q == timer_cmp0_value_out_w);
wire match0_pulse_w = match0_now_w & ~match0_d_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    match0_d_q <= 1'b0;
else
    match0_d_q <= match0_now_w;

wire presc0_tick_w = (timer0_presc_cnt_q == (timer_prescale0_div_eff_w - 16'd1));

always @ (posedge clk_i or posedge rst_i)
if (rst_i) begin
    timer0_value_q      <= 32'b0;
    timer0_presc_cnt_q  <= 16'd0;
    timer0_post_cnt_q   <= 8'd0;
end else if (timer_val0_wr_req_w) begin
    // escrita em VAL0 carrega contador e reseta prescaler (e post para previsibilidade)
    timer0_value_q     <= timer_val0_current_out_w;
    timer0_presc_cnt_q <= 16'd0;
    timer0_post_cnt_q  <= 8'd0;
end else if (timer_ctrl0_enable_out_w) begin
    // Se houve match e AUTORELOAD=1, zera imediatamente (período bem definido)
    if (match0_pulse_w && timer_ctrl0_autoreload_out_w) begin
        timer0_value_q     <= 32'd0;
        timer0_presc_cnt_q <= 16'd0;
        // NÃO zera post_cnt aqui, porque ele é justamente quem faz a divisão dos eventos.
        // (mantém para que POST_DIV conte matches consecutivos)
    end else begin
        // prescaler normal
        if (presc0_tick_w) begin
            timer0_presc_cnt_q <= 16'd0;
            timer0_value_q     <= timer0_value_q + 32'd1;
        end else begin
            timer0_presc_cnt_q <= timer0_presc_cnt_q + 16'd1;
        end
    end
end

assign timer_val0_current_in_w = timer0_value_q;

// Lógica de match + postscaler + flags sticky (com W1C combinado)
always @ (posedge clk_i or posedge rst_i)
if (rst_i) begin
    timer0_match_pend_q <= 1'b0;
    timer0_irq_pend_q   <= 1'b0;
end else if (write_en_w && (cfg_awaddr_i[7:0] == `TIMER_STATUS0)) begin
    // Write-1-to-clear (W1C)
    if (cfg_wdata_i[0]) timer0_match_pend_q <= 1'b0;
    if (cfg_wdata_i[1]) timer0_irq_pend_q   <= 1'b0;
end else if (timer_ctrl0_enable_out_w && match0_pulse_w) begin
    // Set flags on match
    timer0_match_pend_q <= 1'b1;
    if (timer0_post_cnt_q == (timer_postscale0_div_eff_w - 8'd1)) begin
        timer0_post_cnt_q <= 8'd0;
        if (timer_ctrl0_interrupt_out_w)
            timer0_irq_pend_q <= 1'b1;
    end else begin
        timer0_post_cnt_q <= timer0_post_cnt_q + 8'd1;
    end
end

// IRQ efetiva do Timer0: pendente & habilitada & enable do timer
wire timer0_irq_w = timer0_irq_pend_q &&
                    timer_ctrl0_interrupt_out_w &&
                    timer_ctrl0_enable_out_w;


//-----------------------------------------------------------------
// IRQ output
//-----------------------------------------------------------------
reg intr_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    intr_q <= 1'b0;
else if (timer0_irq_w)
    intr_q <= 1'b1;
else
    intr_q <= 1'b0;

//-----------------------------------------------------------------
// Assignments
//-----------------------------------------------------------------
assign intr_o = intr_q;

endmodule
