`include "buscmd.vh"

module cpu(
  input clk,
  input rst);

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			bfs_csr_error;		// From bfs of bfs_core.v
  wire [31:0]		bfs_csr_rdata;		// From bfs of bfs_core.v
  wire			bfs_csr_valid;		// From bfs of bfs_core.v
  wire [31:0]		bfs_dc_addr;		// From bfs of bfs_core.v
  wire [1:0]		bfs_dc_op;		// From bfs of bfs_core.v
  wire			bfs_dc_req;		// From bfs of bfs_core.v
  wire [63:0]		bfs_dc_wdata;		// From bfs of bfs_core.v
  wire [15:0]		brpred_bptag;		// From brpred of brpred.v
  wire			brpred_bptaken;		// From brpred of brpred.v
  wire [31:6]		bus_addr;		// From bus of bus.v
  wire			bus_bfs_grant;		// From bus of bus.v
  wire [2:0]		bus_cmd;		// From bus of bus.v
  wire [63:0]		bus_data;		// From bus of bus.v
  wire			bus_dramctl_grant;	// From bus of bus.v
  wire			bus_hit;		// From bus of bus.v
  wire			bus_l2_grant;		// From bus of bus.v
  wire			bus_nack;		// From bus of bus.v
  wire			bus_rom_grant;		// From bus of bus.v
  wire [4:0]		bus_tag;		// From bus of bus.v
  wire			bus_valid;		// From bus of bus.v
  wire [3:0]		csr_bfs_addr;		// From csr of csr.v
  wire			csr_bfs_valid;		// From csr of csr.v
  wire [31:0]		csr_bfs_wdata;		// From csr of csr.v
  wire			csr_bfs_wen;		// From csr of csr.v
  wire [4:0]		csr_ecause;		// From csr of csr.v
  wire			csr_error;		// From csr of csr.v
  wire [5:0]		csr_rd;			// From csr of csr.v
  wire [31:0]		csr_result;		// From csr of csr.v
  wire [6:0]		csr_robid;		// From csr of csr.v
  wire			csr_stall;		// From csr of csr.v
  wire [31:2]		csr_tvec;		// From csr of csr.v
  wire			csr_valid;		// From csr of csr.v
  wire [31:2]		dcache_l2fifo_addr;	// From dcache of dcache.v
  wire			dcache_l2fifo_req;	// From dcache of dcache.v
  wire [31:0]		dcache_l2fifo_wdata;	// From dcache of dcache.v
  wire			dcache_l2fifo_wen;	// From dcache of dcache.v
  wire [3:0]		dcache_l2fifo_wmask;	// From dcache of dcache.v
  wire			dcache_lsq_error;	// From dcache of dcache.v
  wire [3:0]		dcache_lsq_lsqid;	// From dcache of dcache.v
  wire [31:0]		dcache_lsq_rdata;	// From dcache of dcache.v
  wire			dcache_lsq_ready;	// From dcache of dcache.v
  wire			dcache_lsq_valid;	// From dcache of dcache.v
  wire [31:2]		decode_addr;		// From decode of decode.v
  wire [15:0]		decode_bptag;		// From decode of decode.v
  wire			decode_bptaken;		// From decode of decode.v
  wire			decode_csr_access;	// From decode of decode.v
  wire [1:0]		decode_ecause;		// From decode of decode.v
  wire			decode_error;		// From decode of decode.v
  wire			decode_forward;		// From decode of decode.v
  wire [31:0]		decode_imm;		// From decode of decode.v
  wire			decode_inhibit;		// From decode of decode.v
  wire [5:0]		decode_rd;		// From decode of decode.v
  wire			decode_rename_valid;	// From decode of decode.v
  wire [6:0]		decode_retop;		// From decode of decode.v
  wire			decode_rob_valid;	// From decode of decode.v
  wire [6:0]		decode_robid;		// From decode of decode.v
  wire [4:0]		decode_rs1;		// From decode of decode.v
  wire [4:0]		decode_rs2;		// From decode of decode.v
  wire [4:0]		decode_rsop;		// From decode of decode.v
  wire			decode_stall;		// From decode of decode.v
  wire [31:2]		decode_target;		// From decode of decode.v
  wire			decode_uses_imm;	// From decode of decode.v
  wire			decode_uses_memory;	// From decode of decode.v
  wire			decode_uses_pc;		// From decode of decode.v
  wire			decode_uses_rs1;	// From decode of decode.v
  wire			decode_uses_rs2;	// From decode of decode.v
  wire [31:6]		dramctl_bus_addr;	// From dramctl of dramctl.v
  wire [2:0]		dramctl_bus_cmd;	// From dramctl of dramctl.v
  wire [63:0]		dramctl_bus_data;	// From dramctl of dramctl.v
  wire			dramctl_bus_nack;	// From dramctl of dramctl.v
  wire			dramctl_bus_req;	// From dramctl of dramctl.v
  wire [4:0]		dramctl_bus_tag;	// From dramctl of dramctl.v
  wire			exers_mcalu0_issue;	// From exers of exers.v
  wire			exers_mcalu1_issue;	// From exers of exers.v
  wire [4:0]		exers_mcalu_op;		// From exers of exers.v
  wire [31:0]		exers_op1;		// From exers of exers.v
  wire [31:0]		exers_op2;		// From exers of exers.v
  wire [5:0]		exers_rd;		// From exers of exers.v
  wire [6:0]		exers_robid;		// From exers of exers.v
  wire			exers_scalu0_issue;	// From exers of exers.v
  wire			exers_scalu1_issue;	// From exers of exers.v
  wire [4:0]		exers_scalu_op;		// From exers of exers.v
  wire			exers_stall;		// From exers of exers.v
  wire [31:2]		fetch_bp_addr;		// From fetch of fetch.v
  wire			fetch_bp_req;		// From fetch of fetch.v
  wire [31:1]		fetch_de_addr;		// From fetch of fetch.v
  wire [15:0]		fetch_de_bptag;		// From fetch of fetch.v
  wire			fetch_de_bptaken;	// From fetch of fetch.v
  wire			fetch_de_error;		// From fetch of fetch.v
  wire [31:0]		fetch_de_insn;		// From fetch of fetch.v
  wire			fetch_de_valid;		// From fetch of fetch.v
  wire [31:2]		fetch_ic_addr;		// From fetch of fetch.v
  wire			fetch_ic_flush;		// From fetch of fetch.v
  wire			fetch_ic_req;		// From fetch of fetch.v
  wire [31:0]		icache_data;		// From icache of icache.v
  wire			icache_error;		// From icache of icache.v
  wire			icache_ready;		// From icache of icache.v
  wire			icache_valid;		// From icache of icache.v
  wire			inv_ready;		// From dcache of dcache.v
  wire [31:6]		l2_bus_addr;		// From l2 of l2.v
  wire [2:0]		l2_bus_cmd;		// From l2 of l2.v
  wire [63:0]		l2_bus_data;		// From l2 of l2.v
  wire			l2_bus_hit;		// From l2 of l2.v
  wire			l2_bus_nack;		// From l2 of l2.v
  wire			l2_bus_req;		// From l2 of l2.v
  wire [4:0]		l2_bus_tag;		// From l2 of l2.v
  wire			l2_idle;		// From l2 of l2.v
  wire [31:6]		l2_inv_addr;		// From l2 of l2.v
  wire			l2_inv_valid;		// From l2 of l2.v
  wire			l2_resp_error;		// From l2 of l2.v
  wire [63:0]		l2_resp_rdata;		// From l2 of l2.v
  wire			l2_resp_valid;		// From l2 of l2.v
  wire			l2fifo_dc_ready;	// From l2fifo of l2fifo.v
  wire [31:2]		l2fifo_l2_addr;		// From l2fifo of l2fifo.v
  wire			l2fifo_l2_req;		// From l2fifo of l2fifo.v
  wire [31:0]		l2fifo_l2_wdata;	// From l2fifo of l2fifo.v
  wire			l2fifo_l2_wen;		// From l2fifo of l2fifo.v
  wire [3:0]		l2fifo_l2_wmask;	// From l2fifo of l2fifo.v
  wire [31:0]		lsq_dc_addr;		// From lsq of lsq.v
  wire			lsq_dc_flush;		// From lsq of lsq.v
  wire [3:0]		lsq_dc_lsqid;		// From lsq of lsq.v
  wire [3:0]		lsq_dc_op;		// From lsq of lsq.v
  wire			lsq_dc_req;		// From lsq of lsq.v
  wire [31:0]		lsq_dc_wdata;		// From lsq of lsq.v
  wire			lsq_stall;		// From lsq of lsq.v
  wire [4:0]		lsq_wb_ecause;		// From lsq of lsq.v
  wire			lsq_wb_error;		// From lsq of lsq.v
  wire [5:0]		lsq_wb_rd;		// From lsq of lsq.v
  wire [31:0]		lsq_wb_result;		// From lsq of lsq.v
  wire [6:0]		lsq_wb_robid;		// From lsq of lsq.v
  wire			lsq_wb_valid;		// From lsq of lsq.v
  wire [4:0]		mcalu0_ecause;		// From mcalu0 of mcalu.v
  wire			mcalu0_error;		// From mcalu0 of mcalu.v
  wire [5:0]		mcalu0_rd;		// From mcalu0 of mcalu.v
  wire [31:0]		mcalu0_result;		// From mcalu0 of mcalu.v
  wire [6:0]		mcalu0_robid;		// From mcalu0 of mcalu.v
  wire			mcalu0_stall;		// From mcalu0 of mcalu.v
  wire			mcalu0_valid;		// From mcalu0 of mcalu.v
  wire [4:0]		mcalu1_ecause;		// From mcalu1 of mcalu.v
  wire			mcalu1_error;		// From mcalu1 of mcalu.v
  wire [5:0]		mcalu1_rd;		// From mcalu1 of mcalu.v
  wire [31:0]		mcalu1_result;		// From mcalu1 of mcalu.v
  wire [6:0]		mcalu1_robid;		// From mcalu1 of mcalu.v
  wire			mcalu1_stall;		// From mcalu1 of mcalu.v
  wire			mcalu1_valid;		// From mcalu1 of mcalu.v
  wire [31:0]		rat_rs1_tagval;		// From rat of rat.v
  wire			rat_rs1_valid;		// From rat of rat.v
  wire [31:0]		rat_rs2_tagval;		// From rat of rat.v
  wire			rat_rs2_valid;		// From rat of rat.v
  wire			rename_alloc;		// From rename of rename.v
  wire			rename_csr_write;	// From rename of rename.v
  wire			rename_exers_write;	// From rename of rename.v
  wire [31:0]		rename_imm;		// From rename of rename.v
  wire			rename_inhibit;		// From rename of rename.v
  wire			rename_lsq_write;	// From rename of rename.v
  wire [4:0]		rename_op;		// From rename of rename.v
  wire [31:0]		rename_op1;		// From rename of rename.v
  wire			rename_op1ready;	// From rename of rename.v
  wire [31:0]		rename_op2;		// From rename of rename.v
  wire			rename_op2ready;	// From rename of rename.v
  wire [5:0]		rename_rd;		// From rename of rename.v
  wire [6:0]		rename_robid;		// From rename of rename.v
  wire [4:0]		rename_rs1;		// From rename of rename.v
  wire [4:0]		rename_rs2;		// From rename of rename.v
  wire			rename_stall;		// From rename of rename.v
  wire [31:2]		rename_wb_result;	// From rename of rename.v
  wire			rename_wb_valid;	// From rename of rename.v
  wire			resp_ready;		// From dcache of dcache.v
  wire [4:0]		rob_csr_ecause;		// From rob of rob.v
  wire [31:2]		rob_csr_epc;		// From rob of rob.v
  wire [31:0]		rob_csr_tval;		// From rob of rob.v
  wire			rob_csr_valid;		// From rob of rob.v
  wire			rob_flush;		// From rob of rob.v
  wire [31:2]		rob_flush_pc;		// From rob of rob.v
  wire			rob_full;		// From rob of rob.v
  wire			rob_rename_ishead;	// From rob of rob.v
  wire [15:0]		rob_ret_bptag;		// From rob of rob.v
  wire			rob_ret_bptaken;	// From rob of rob.v
  wire			rob_ret_branch;		// From rob of rob.v
  wire			rob_ret_commit;		// From rob of rob.v
  wire			rob_ret_csr;		// From rob of rob.v
  wire [4:0]		rob_ret_rd;		// From rob of rob.v
  wire [31:0]		rob_ret_result;		// From rob of rob.v
  wire			rob_ret_store;		// From rob of rob.v
  wire			rob_ret_valid;		// From rob of rob.v
  wire [6:0]		rob_robid;		// From rob of rob.v
  wire [31:6]		rom_bus_addr;		// From rom of rom.v
  wire [2:0]		rom_bus_cmd;		// From rom of rom.v
  wire [63:0]		rom_bus_data;		// From rom of rom.v
  wire			rom_bus_nack;		// From rom of rom.v
  wire			rom_bus_req;		// From rom of rom.v
  wire [4:0]		rom_bus_tag;		// From rom of rom.v
  wire [4:0]		scalu0_ecause;		// From scalu0 of scalu.v
  wire			scalu0_error;		// From scalu0 of scalu.v
  wire [5:0]		scalu0_rd;		// From scalu0 of scalu.v
  wire [31:0]		scalu0_result;		// From scalu0 of scalu.v
  wire [6:0]		scalu0_robid;		// From scalu0 of scalu.v
  wire			scalu0_stall;		// From scalu0 of scalu.v
  wire			scalu0_valid;		// From scalu0 of scalu.v
  wire [4:0]		scalu1_ecause;		// From scalu1 of scalu.v
  wire			scalu1_error;		// From scalu1 of scalu.v
  wire [5:0]		scalu1_rd;		// From scalu1 of scalu.v
  wire [31:0]		scalu1_result;		// From scalu1 of scalu.v
  wire [6:0]		scalu1_robid;		// From scalu1 of scalu.v
  wire			scalu1_stall;		// From scalu1 of scalu.v
  wire			scalu1_valid;		// From scalu1 of scalu.v
  wire [4:0]		wb_ecause;		// From wb of wb.v
  wire			wb_error;		// From wb of wb.v
  wire			wb_lsq_stall;		// From wb of wb.v
  wire			wb_mcalu0_stall;	// From wb of wb.v
  wire			wb_mcalu1_stall;	// From wb of wb.v
  wire [5:0]		wb_rd;			// From wb of wb.v
  wire [31:0]		wb_result;		// From wb of wb.v
  wire [6:0]		wb_robid;		// From wb of wb.v
  wire			wb_scalu0_stall;	// From wb of wb.v
  wire			wb_scalu1_stall;	// From wb of wb.v
  wire			wb_valid;		// From wb of wb.v
  // End of automatics

  wire [2:0]  bfs_bus_cmd;
  wire [4:0]  bfs_bus_tag;
  wire [31:6] bfs_bus_addr;
  wire [63:0] bfs_bus_data;
  wire [63:0] dc_rdata;
  wire [1:0]  dc_op;

  brpred brpred(
    /*AUTOINST*/
		// Outputs
		.brpred_bptag		(brpred_bptag[15:0]),
		.brpred_bptaken		(brpred_bptaken),
		// Inputs
		.clk			(clk),
		.rst			(rst),
		.fetch_bp_req		(fetch_bp_req),
		.fetch_bp_addr		(fetch_bp_addr[31:2]),
		.rob_flush		(rob_flush),
		.rob_ret_branch		(rob_ret_branch),
		.rob_ret_bptag		(rob_ret_bptag[15:0]),
		.rob_ret_bptaken	(rob_ret_bptaken));

  csr csr(
    /*AUTOINST*/
	  // Outputs
	  .csr_stall			(csr_stall),
	  .csr_valid			(csr_valid),
	  .csr_error			(csr_error),
	  .csr_ecause			(csr_ecause[4:0]),
	  .csr_robid			(csr_robid[6:0]),
	  .csr_rd			(csr_rd[5:0]),
	  .csr_result			(csr_result[31:0]),
	  .csr_tvec			(csr_tvec[31:2]),
	  .csr_bfs_valid		(csr_bfs_valid),
	  .csr_bfs_addr			(csr_bfs_addr[3:0]),
	  .csr_bfs_wen			(csr_bfs_wen),
	  .csr_bfs_wdata		(csr_bfs_wdata[31:0]),
	  // Inputs
	  .clk				(clk),
	  .rst				(rst),
	  .rename_csr_write		(rename_csr_write),
	  .rename_op			(rename_op[4:0]),
	  .rename_robid			(rename_robid[6:0]),
	  .rename_rd			(rename_rd[5:0]),
	  .rename_op1			(rename_op1[31:0]),
	  .rename_imm			(rename_imm[31:0]),
	  .rob_flush			(rob_flush),
	  .rob_ret_valid		(rob_ret_valid),
	  .rob_ret_csr			(rob_ret_csr),
	  .rob_csr_valid		(rob_csr_valid),
	  .rob_csr_epc			(rob_csr_epc[31:2]),
	  .rob_csr_ecause		(rob_csr_ecause[4:0]),
	  .rob_csr_tval			(rob_csr_tval[31:0]),
	  .bfs_csr_valid		(bfs_csr_valid),
	  .bfs_csr_error		(bfs_csr_error),
	  .bfs_csr_rdata		(bfs_csr_rdata[31:0]),
	  .l2fifo_l2_req		(l2fifo_l2_req));

  dcache dcache(
    /*AUTOINST*/
		// Outputs
		.dcache_lsq_ready	(dcache_lsq_ready),
		.dcache_lsq_valid	(dcache_lsq_valid),
		.dcache_lsq_error	(dcache_lsq_error),
		.dcache_lsq_lsqid	(dcache_lsq_lsqid[3:0]),
		.dcache_lsq_rdata	(dcache_lsq_rdata[31:0]),
		.dcache_l2fifo_req	(dcache_l2fifo_req),
		.dcache_l2fifo_addr	(dcache_l2fifo_addr[31:2]),
		.dcache_l2fifo_wen	(dcache_l2fifo_wen),
		.dcache_l2fifo_wmask	(dcache_l2fifo_wmask[3:0]),
		.dcache_l2fifo_wdata	(dcache_l2fifo_wdata[31:0]),
		.resp_ready		(resp_ready),
		.inv_ready		(inv_ready),
		// Inputs
		.clk			(clk),
		.rst			(rst),
		.lsq_dc_req		(lsq_dc_req),
		.lsq_dc_op		(lsq_dc_op[3:0]),
		.lsq_dc_addr		(lsq_dc_addr[31:0]),
		.lsq_dc_lsqid		(lsq_dc_lsqid[3:0]),
		.lsq_dc_wdata		(lsq_dc_wdata[31:0]),
		.lsq_dc_flush		(lsq_dc_flush),
		.l2fifo_dc_ready	(l2fifo_dc_ready),
		.l2_resp_valid		(l2_resp_valid),
		.l2_resp_error		(l2_resp_error),
		.l2_resp_rdata		(l2_resp_rdata[63:0]),
		.l2_inv_valid		(l2_inv_valid),
		.l2_inv_addr		(l2_inv_addr[31:6]));

  decode decode(
    /*AUTOINST*/
		// Outputs
		.decode_stall		(decode_stall),
		.decode_rob_valid	(decode_rob_valid),
		.decode_error		(decode_error),
		.decode_ecause		(decode_ecause[1:0]),
		.decode_retop		(decode_retop[6:0]),
		.decode_bptag		(decode_bptag[15:0]),
		.decode_bptaken		(decode_bptaken),
		.decode_rd		(decode_rd[5:0]),
		.decode_addr		(decode_addr[31:2]),
		.decode_forward		(decode_forward),
		.decode_target		(decode_target[31:2]),
		.decode_rename_valid	(decode_rename_valid),
		.decode_rsop		(decode_rsop[4:0]),
		.decode_robid		(decode_robid[6:0]),
		.decode_uses_rs1	(decode_uses_rs1),
		.decode_uses_rs2	(decode_uses_rs2),
		.decode_uses_imm	(decode_uses_imm),
		.decode_uses_memory	(decode_uses_memory),
		.decode_uses_pc		(decode_uses_pc),
		.decode_csr_access	(decode_csr_access),
		.decode_inhibit		(decode_inhibit),
		.decode_rs1		(decode_rs1[4:0]),
		.decode_rs2		(decode_rs2[4:0]),
		.decode_imm		(decode_imm[31:0]),
		// Inputs
		.clk			(clk),
		.rst			(rst),
		.fetch_de_valid		(fetch_de_valid),
		.fetch_de_error		(fetch_de_error),
		.fetch_de_addr		(fetch_de_addr[31:1]),
		.fetch_de_insn		(fetch_de_insn[31:0]),
		.fetch_de_bptag		(fetch_de_bptag[15:0]),
		.fetch_de_bptaken	(fetch_de_bptaken),
		.rob_flush		(rob_flush),
		.rob_full		(rob_full),
		.rob_robid		(rob_robid[6:0]),
		.rename_stall		(rename_stall));

  exers exers(
    /*AUTOINST*/
	      // Outputs
	      .exers_stall		(exers_stall),
	      .exers_robid		(exers_robid[6:0]),
	      .exers_rd			(exers_rd[5:0]),
	      .exers_op1		(exers_op1[31:0]),
	      .exers_op2		(exers_op2[31:0]),
	      .exers_scalu0_issue	(exers_scalu0_issue),
	      .exers_scalu1_issue	(exers_scalu1_issue),
	      .exers_scalu_op		(exers_scalu_op[4:0]),
	      .exers_mcalu0_issue	(exers_mcalu0_issue),
	      .exers_mcalu1_issue	(exers_mcalu1_issue),
	      .exers_mcalu_op		(exers_mcalu_op[4:0]),
	      // Inputs
	      .clk			(clk),
	      .rst			(rst),
	      .rename_exers_write	(rename_exers_write),
	      .rename_op		(rename_op[4:0]),
	      .rename_robid		(rename_robid[6:0]),
	      .rename_rd		(rename_rd[5:0]),
	      .rename_op1ready		(rename_op1ready),
	      .rename_op1		(rename_op1[31:0]),
	      .rename_op2ready		(rename_op2ready),
	      .rename_op2		(rename_op2[31:0]),
	      .scalu0_stall		(scalu0_stall),
	      .scalu1_stall		(scalu1_stall),
	      .mcalu0_stall		(mcalu0_stall),
	      .mcalu1_stall		(mcalu1_stall),
	      .wb_valid			(wb_valid),
	      .wb_error			(wb_error),
	      .wb_robid			(wb_robid[6:0]),
	      .wb_rd			(wb_rd[5:0]),
	      .wb_result		(wb_result[31:0]),
	      .rob_flush		(rob_flush));

  fetch fetch(
    /*AUTOINST*/
	      // Outputs
	      .fetch_ic_req		(fetch_ic_req),
	      .fetch_ic_addr		(fetch_ic_addr[31:2]),
	      .fetch_ic_flush		(fetch_ic_flush),
	      .fetch_bp_req		(fetch_bp_req),
	      .fetch_bp_addr		(fetch_bp_addr[31:2]),
	      .fetch_de_valid		(fetch_de_valid),
	      .fetch_de_error		(fetch_de_error),
	      .fetch_de_addr		(fetch_de_addr[31:1]),
	      .fetch_de_insn		(fetch_de_insn[31:0]),
	      .fetch_de_bptag		(fetch_de_bptag[15:0]),
	      .fetch_de_bptaken		(fetch_de_bptaken),
	      // Inputs
	      .clk			(clk),
	      .rst			(rst),
	      .icache_ready		(icache_ready),
	      .icache_valid		(icache_valid),
	      .icache_error		(icache_error),
	      .icache_data		(icache_data[31:0]),
	      .brpred_bptag		(brpred_bptag[15:0]),
	      .brpred_bptaken		(brpred_bptaken),
	      .decode_stall		(decode_stall),
	      .rob_flush		(rob_flush),
	      .rob_flush_pc		(rob_flush_pc[31:2]));

  icache icache(
    /*AUTOINST*/
		// Outputs
		.icache_ready		(icache_ready),
		.icache_valid		(icache_valid),
		.icache_error		(icache_error),
		.icache_data		(icache_data[31:0]),
		// Inputs
		.clk			(clk),
		.rst			(rst),
		.fetch_ic_req		(fetch_ic_req),
		.fetch_ic_addr		(fetch_ic_addr[31:2]),
		.fetch_ic_flush		(fetch_ic_flush));

  lsq lsq(
    /*AUTOINST*/
	  // Outputs
	  .lsq_stall			(lsq_stall),
	  .lsq_dc_req			(lsq_dc_req),
	  .lsq_dc_op			(lsq_dc_op[3:0]),
	  .lsq_dc_addr			(lsq_dc_addr[31:0]),
	  .lsq_dc_lsqid			(lsq_dc_lsqid[3:0]),
	  .lsq_dc_wdata			(lsq_dc_wdata[31:0]),
	  .lsq_dc_flush			(lsq_dc_flush),
	  .lsq_wb_valid			(lsq_wb_valid),
	  .lsq_wb_error			(lsq_wb_error),
	  .lsq_wb_ecause		(lsq_wb_ecause[4:0]),
	  .lsq_wb_robid			(lsq_wb_robid[6:0]),
	  .lsq_wb_rd			(lsq_wb_rd[5:0]),
	  .lsq_wb_result		(lsq_wb_result[31:0]),
	  // Inputs
	  .clk				(clk),
	  .rst				(rst),
	  .rename_lsq_write		(rename_lsq_write),
	  .rename_op			(rename_op[3:0]),
	  .rename_robid			(rename_robid[6:0]),
	  .rename_rd			(rename_rd[5:0]),
	  .rename_op1ready		(rename_op1ready),
	  .rename_op1			(rename_op1[31:0]),
	  .rename_op2ready		(rename_op2ready),
	  .rename_op2			(rename_op2[31:0]),
	  .rename_imm			(rename_imm[31:0]),
	  .dcache_lsq_ready		(dcache_lsq_ready),
	  .dcache_lsq_valid		(dcache_lsq_valid),
	  .dcache_lsq_error		(dcache_lsq_error),
	  .dcache_lsq_lsqid		(dcache_lsq_lsqid[3:0]),
	  .dcache_lsq_rdata		(dcache_lsq_rdata[31:0]),
	  .wb_lsq_stall			(wb_lsq_stall),
	  .wb_valid			(wb_valid),
	  .wb_error			(wb_error),
	  .wb_robid			(wb_robid[6:0]),
	  .wb_rd			(wb_rd[5:0]),
	  .wb_result			(wb_result[31:0]),
	  .rob_flush			(rob_flush),
	  .rob_ret_store		(rob_ret_store));

  /*
   mcalu AUTO_TEMPLATE(
   .exers_mcalu_issue(exers_mcalu@_issue),
   .mcalu_stall(mcalu@_stall),
   .mcalu_valid(mcalu@_valid),
   .mcalu_error(mcalu@_error),
   .mcalu_ecause(mcalu@_ecause[]),
   .mcalu_robid(mcalu@_robid[]),
   .mcalu_rd(mcalu@_rd[]),
   .mcalu_result(mcalu@_result[]),
   .wb_mcalu_stall(wb_mcalu@_stall));
   */

  mcalu mcalu0(
    /*AUTOINST*/
	       // Outputs
	       .mcalu_stall		(mcalu0_stall),		 // Templated
	       .mcalu_valid		(mcalu0_valid),		 // Templated
	       .mcalu_error		(mcalu0_error),		 // Templated
	       .mcalu_ecause		(mcalu0_ecause[4:0]),	 // Templated
	       .mcalu_robid		(mcalu0_robid[6:0]),	 // Templated
	       .mcalu_rd		(mcalu0_rd[5:0]),	 // Templated
	       .mcalu_result		(mcalu0_result[31:0]),	 // Templated
	       // Inputs
	       .clk			(clk),
	       .rst			(rst),
	       .exers_mcalu_issue	(exers_mcalu0_issue),	 // Templated
	       .exers_mcalu_op		(exers_mcalu_op[4:0]),
	       .exers_robid		(exers_robid[6:0]),
	       .exers_rd		(exers_rd[5:0]),
	       .exers_op1		(exers_op1[31:0]),
	       .exers_op2		(exers_op2[31:0]),
	       .wb_mcalu_stall		(wb_mcalu0_stall),	 // Templated
	       .rob_flush		(rob_flush));

  mcalu mcalu1(
    /*AUTOINST*/
	       // Outputs
	       .mcalu_stall		(mcalu1_stall),		 // Templated
	       .mcalu_valid		(mcalu1_valid),		 // Templated
	       .mcalu_error		(mcalu1_error),		 // Templated
	       .mcalu_ecause		(mcalu1_ecause[4:0]),	 // Templated
	       .mcalu_robid		(mcalu1_robid[6:0]),	 // Templated
	       .mcalu_rd		(mcalu1_rd[5:0]),	 // Templated
	       .mcalu_result		(mcalu1_result[31:0]),	 // Templated
	       // Inputs
	       .clk			(clk),
	       .rst			(rst),
	       .exers_mcalu_issue	(exers_mcalu1_issue),	 // Templated
	       .exers_mcalu_op		(exers_mcalu_op[4:0]),
	       .exers_robid		(exers_robid[6:0]),
	       .exers_rd		(exers_rd[5:0]),
	       .exers_op1		(exers_op1[31:0]),
	       .exers_op2		(exers_op2[31:0]),
	       .wb_mcalu_stall		(wb_mcalu1_stall),	 // Templated
	       .rob_flush		(rob_flush));

  rat rat(
    /*AUTOINST*/
	  // Outputs
	  .rat_rs1_valid		(rat_rs1_valid),
	  .rat_rs1_tagval		(rat_rs1_tagval[31:0]),
	  .rat_rs2_valid		(rat_rs2_valid),
	  .rat_rs2_tagval		(rat_rs2_tagval[31:0]),
	  // Inputs
	  .clk				(clk),
	  .rst				(rst),
	  .rename_rs1			(rename_rs1[4:0]),
	  .rename_rs2			(rename_rs2[4:0]),
	  .rename_alloc			(rename_alloc),
	  .rename_rd			(rename_rd[4:0]),
	  .rename_robid			(rename_robid[6:0]),
	  .wb_valid			(wb_valid),
	  .wb_error			(wb_error),
	  .wb_robid			(wb_robid[6:0]),
	  .wb_rd			(wb_rd[5:0]),
	  .wb_result			(wb_result[31:0]),
	  .rob_flush			(rob_flush),
	  .rob_ret_commit		(rob_ret_commit),
	  .rob_ret_rd			(rob_ret_rd[4:0]),
	  .rob_ret_result		(rob_ret_result[31:0]));

  rename rename(
    /*AUTOINST*/
		// Outputs
		.rename_stall		(rename_stall),
		.rename_rs1		(rename_rs1[4:0]),
		.rename_rs2		(rename_rs2[4:0]),
		.rename_alloc		(rename_alloc),
		.rename_rd		(rename_rd[5:0]),
		.rename_robid		(rename_robid[6:0]),
		.rename_exers_write	(rename_exers_write),
		.rename_lsq_write	(rename_lsq_write),
		.rename_csr_write	(rename_csr_write),
		.rename_op		(rename_op[4:0]),
		.rename_op1ready	(rename_op1ready),
		.rename_op1		(rename_op1[31:0]),
		.rename_op2ready	(rename_op2ready),
		.rename_op2		(rename_op2[31:0]),
		.rename_imm		(rename_imm[31:0]),
		.rename_wb_valid	(rename_wb_valid),
		.rename_wb_result	(rename_wb_result[31:2]),
		.rename_inhibit		(rename_inhibit),
		// Inputs
		.clk			(clk),
		.rst			(rst),
		.decode_rename_valid	(decode_rename_valid),
		.decode_addr		(decode_addr[31:2]),
		.decode_rsop		(decode_rsop[4:0]),
		.decode_robid		(decode_robid[6:0]),
		.decode_rd		(decode_rd[5:0]),
		.decode_uses_rs1	(decode_uses_rs1),
		.decode_uses_rs2	(decode_uses_rs2),
		.decode_uses_imm	(decode_uses_imm),
		.decode_uses_memory	(decode_uses_memory),
		.decode_uses_pc		(decode_uses_pc),
		.decode_csr_access	(decode_csr_access),
		.decode_forward		(decode_forward),
		.decode_inhibit		(decode_inhibit),
		.decode_target		(decode_target[31:2]),
		.decode_rs1		(decode_rs1[4:0]),
		.decode_rs2		(decode_rs2[4:0]),
		.decode_imm		(decode_imm[31:0]),
		.rat_rs1_valid		(rat_rs1_valid),
		.rat_rs1_tagval		(rat_rs1_tagval[31:0]),
		.rat_rs2_valid		(rat_rs2_valid),
		.rat_rs2_tagval		(rat_rs2_tagval[31:0]),
		.exers_stall		(exers_stall),
		.lsq_stall		(lsq_stall),
		.csr_stall		(csr_stall),
		.rob_flush		(rob_flush),
		.rob_rename_ishead	(rob_rename_ishead));

  rob rob(
    /*AUTOINST*/
	  // Outputs
	  .rob_full			(rob_full),
	  .rob_robid			(rob_robid[6:0]),
	  .rob_rename_ishead		(rob_rename_ishead),
	  .rob_flush			(rob_flush),
	  .rob_flush_pc			(rob_flush_pc[31:2]),
	  .rob_ret_commit		(rob_ret_commit),
	  .rob_ret_rd			(rob_ret_rd[4:0]),
	  .rob_ret_result		(rob_ret_result[31:0]),
	  .rob_ret_branch		(rob_ret_branch),
	  .rob_ret_bptag		(rob_ret_bptag[15:0]),
	  .rob_ret_bptaken		(rob_ret_bptaken),
	  .rob_ret_store		(rob_ret_store),
	  .rob_ret_valid		(rob_ret_valid),
	  .rob_ret_csr			(rob_ret_csr),
	  .rob_csr_valid		(rob_csr_valid),
	  .rob_csr_epc			(rob_csr_epc[31:2]),
	  .rob_csr_ecause		(rob_csr_ecause[4:0]),
	  .rob_csr_tval			(rob_csr_tval[31:0]),
	  // Inputs
	  .clk				(clk),
	  .rst				(rst),
	  .decode_rob_valid		(decode_rob_valid),
	  .decode_error			(decode_error),
	  .decode_ecause		(decode_ecause[1:0]),
	  .decode_retop			(decode_retop[6:0]),
	  .decode_addr			(decode_addr[31:2]),
	  .decode_rd			(decode_rd[5:0]),
	  .decode_bptag			(decode_bptag[15:0]),
	  .decode_bptaken		(decode_bptaken),
	  .decode_forward		(decode_forward),
	  .decode_target		(decode_target[31:2]),
	  .rename_inhibit		(rename_inhibit),
	  .rename_robid			(rename_robid[6:0]),
	  .wb_valid			(wb_valid),
	  .wb_error			(wb_error),
	  .wb_ecause			(wb_ecause[4:0]),
	  .wb_robid			(wb_robid[6:0]),
	  .wb_result			(wb_result[31:0]),
	  .csr_tvec			(csr_tvec[31:2]));

  /*
   scalu AUTO_TEMPLATE(
   .exers_scalu_issue(exers_scalu@_issue),
   .scalu_stall(scalu@_stall),
   .scalu_valid(scalu@_valid),
   .scalu_error(scalu@_error),
   .scalu_ecause(scalu@_ecause[]),
   .scalu_robid(scalu@_robid[]),
   .scalu_rd(scalu@_rd[]),
   .scalu_result(scalu@_result[]),
   .wb_scalu_stall(wb_scalu@_stall));
   */

  scalu scalu0(
    /*AUTOINST*/
	       // Outputs
	       .scalu_stall		(scalu0_stall),		 // Templated
	       .scalu_valid		(scalu0_valid),		 // Templated
	       .scalu_error		(scalu0_error),		 // Templated
	       .scalu_ecause		(scalu0_ecause[4:0]),	 // Templated
	       .scalu_robid		(scalu0_robid[6:0]),	 // Templated
	       .scalu_rd		(scalu0_rd[5:0]),	 // Templated
	       .scalu_result		(scalu0_result[31:0]),	 // Templated
	       // Inputs
	       .clk			(clk),
	       .rst			(rst),
	       .exers_scalu_issue	(exers_scalu0_issue),	 // Templated
	       .exers_scalu_op		(exers_scalu_op[4:0]),
	       .exers_robid		(exers_robid[6:0]),
	       .exers_rd		(exers_rd[5:0]),
	       .exers_op1		(exers_op1[31:0]),
	       .exers_op2		(exers_op2[31:0]),
	       .wb_scalu_stall		(wb_scalu0_stall),	 // Templated
	       .rob_flush		(rob_flush));

  scalu scalu1(
    /*AUTOINST*/
	       // Outputs
	       .scalu_stall		(scalu1_stall),		 // Templated
	       .scalu_valid		(scalu1_valid),		 // Templated
	       .scalu_error		(scalu1_error),		 // Templated
	       .scalu_ecause		(scalu1_ecause[4:0]),	 // Templated
	       .scalu_robid		(scalu1_robid[6:0]),	 // Templated
	       .scalu_rd		(scalu1_rd[5:0]),	 // Templated
	       .scalu_result		(scalu1_result[31:0]),	 // Templated
	       // Inputs
	       .clk			(clk),
	       .rst			(rst),
	       .exers_scalu_issue	(exers_scalu1_issue),	 // Templated
	       .exers_scalu_op		(exers_scalu_op[4:0]),
	       .exers_robid		(exers_robid[6:0]),
	       .exers_rd		(exers_rd[5:0]),
	       .exers_op1		(exers_op1[31:0]),
	       .exers_op2		(exers_op2[31:0]),
	       .wb_scalu_stall		(wb_scalu1_stall),	 // Templated
	       .rob_flush		(rob_flush));

  wb wb(
    /*AUTOINST*/
	// Outputs
	.wb_scalu0_stall		(wb_scalu0_stall),
	.wb_scalu1_stall		(wb_scalu1_stall),
	.wb_mcalu0_stall		(wb_mcalu0_stall),
	.wb_mcalu1_stall		(wb_mcalu1_stall),
	.wb_lsq_stall			(wb_lsq_stall),
	.wb_valid			(wb_valid),
	.wb_error			(wb_error),
	.wb_ecause			(wb_ecause[4:0]),
	.wb_robid			(wb_robid[6:0]),
	.wb_rd				(wb_rd[5:0]),
	.wb_result			(wb_result[31:0]),
	// Inputs
	.clk				(clk),
	.rst				(rst),
	.rename_wb_valid		(rename_wb_valid),
	.rename_robid			(rename_robid[6:0]),
	.rename_rd			(rename_rd[5:0]),
	.rename_wb_result		(rename_wb_result[31:2]),
	.scalu0_valid			(scalu0_valid),
	.scalu0_error			(scalu0_error),
	.scalu0_ecause			(scalu0_ecause[4:0]),
	.scalu0_robid			(scalu0_robid[6:0]),
	.scalu0_rd			(scalu0_rd[5:0]),
	.scalu0_result			(scalu0_result[31:0]),
	.scalu1_valid			(scalu1_valid),
	.scalu1_error			(scalu1_error),
	.scalu1_ecause			(scalu1_ecause[4:0]),
	.scalu1_robid			(scalu1_robid[6:0]),
	.scalu1_rd			(scalu1_rd[5:0]),
	.scalu1_result			(scalu1_result[31:0]),
	.mcalu0_valid			(mcalu0_valid),
	.mcalu0_error			(mcalu0_error),
	.mcalu0_ecause			(mcalu0_ecause[4:0]),
	.mcalu0_robid			(mcalu0_robid[6:0]),
	.mcalu0_rd			(mcalu0_rd[5:0]),
	.mcalu0_result			(mcalu0_result[31:0]),
	.mcalu1_valid			(mcalu1_valid),
	.mcalu1_error			(mcalu1_error),
	.mcalu1_ecause			(mcalu1_ecause[4:0]),
	.mcalu1_robid			(mcalu1_robid[6:0]),
	.mcalu1_rd			(mcalu1_rd[5:0]),
	.mcalu1_result			(mcalu1_result[31:0]),
	.lsq_wb_valid			(lsq_wb_valid),
	.lsq_wb_error			(lsq_wb_error),
	.lsq_wb_ecause			(lsq_wb_ecause[4:0]),
	.lsq_wb_robid			(lsq_wb_robid[6:0]),
	.lsq_wb_rd			(lsq_wb_rd[5:0]),
	.lsq_wb_result			(lsq_wb_result[31:0]),
	.csr_valid			(csr_valid),
	.csr_error			(csr_error),
	.csr_ecause			(csr_ecause[4:0]),
	.csr_robid			(csr_robid[6:0]),
	.csr_rd				(csr_rd[5:0]),
	.csr_result			(csr_result[31:0]),
	.rob_flush			(rob_flush));

  bus bus(
    /*AUTOINST*/
	  // Outputs
	  .bus_l2_grant			(bus_l2_grant),
	  .bus_bfs_grant		(bus_bfs_grant),
	  .bus_dramctl_grant		(bus_dramctl_grant),
	  .bus_rom_grant		(bus_rom_grant),
	  .bus_valid			(bus_valid),
	  .bus_nack			(bus_nack),
	  .bus_hit			(bus_hit),
	  .bus_cmd			(bus_cmd[2:0]),
	  .bus_tag			(bus_tag[4:0]),
	  .bus_addr			(bus_addr[31:6]),
	  .bus_data			(bus_data[63:0]),
	  // Inputs
	  .clk				(clk),
	  .rst				(rst),
	  .l2_bus_req			(l2_bus_req),
	  .l2_bus_cmd			(l2_bus_cmd[2:0]),
	  .l2_bus_tag			(l2_bus_tag[4:0]),
	  .l2_bus_addr			(l2_bus_addr[31:6]),
	  .l2_bus_data			(l2_bus_data[63:0]),
	  .l2_bus_hit			(l2_bus_hit),
	  .l2_bus_nack			(l2_bus_nack),
	  .bfs_bus_req			(bfs_bus_req),
	  .bfs_bus_cmd			(bfs_bus_cmd[2:0]),
	  .bfs_bus_tag			(bfs_bus_tag[4:0]),
	  .bfs_bus_addr			(bfs_bus_addr[31:6]),
	  .bfs_bus_data			(bfs_bus_data[63:0]),
	  .bfs_bus_hit			(bfs_bus_hit),
	  .bfs_bus_nack			(bfs_bus_nack),
	  .dramctl_bus_req		(dramctl_bus_req),
	  .dramctl_bus_cmd		(dramctl_bus_cmd[2:0]),
	  .dramctl_bus_tag		(dramctl_bus_tag[4:0]),
	  .dramctl_bus_addr		(dramctl_bus_addr[31:6]),
	  .dramctl_bus_data		(dramctl_bus_data[63:0]),
	  .dramctl_bus_nack		(dramctl_bus_nack),
	  .rom_bus_req			(rom_bus_req),
	  .rom_bus_cmd			(rom_bus_cmd[2:0]),
	  .rom_bus_tag			(rom_bus_tag[4:0]),
	  .rom_bus_addr			(rom_bus_addr[31:6]),
	  .rom_bus_data			(rom_bus_data[63:0]),
	  .rom_bus_nack			(rom_bus_nack));

  l2fifo l2fifo(
    /*AUTOINST*/
		// Outputs
		.l2fifo_dc_ready	(l2fifo_dc_ready),
		.l2fifo_l2_req		(l2fifo_l2_req),
		.l2fifo_l2_addr		(l2fifo_l2_addr[31:2]),
		.l2fifo_l2_wen		(l2fifo_l2_wen),
		.l2fifo_l2_wmask	(l2fifo_l2_wmask[3:0]),
		.l2fifo_l2_wdata	(l2fifo_l2_wdata[31:0]),
		// Inputs
		.clk			(clk),
		.rst			(rst),
		.dcache_l2fifo_req	(dcache_l2fifo_req),
		.dcache_l2fifo_addr	(dcache_l2fifo_addr[31:2]),
		.dcache_l2fifo_wen	(dcache_l2fifo_wen),
		.dcache_l2fifo_wmask	(dcache_l2fifo_wmask[3:0]),
		.dcache_l2fifo_wdata	(dcache_l2fifo_wdata[31:0]),
		.l2_l2fifo_ready	(l2_l2fifo_ready));

  l2 #(`BUSID_L2) l2(
    .req_valid(l2fifo_l2_req),
    .req_op(l2fifo_l2_wen ? `OP_WR4 : `OP_RD),
    .req_addr(l2fifo_l2_addr),
    .req_wmask(l2fifo_l2_addr[2] ? {l2fifo_l2_wmask,4'b0} : {4'b0,l2fifo_l2_wmask}),
    .req_wdata({2{l2fifo_l2_wdata}}),
    .l2_req_ready(l2_l2fifo_ready),
    .l2_resp_op(),
    /*AUTOINST*/
		     // Outputs
		     .l2_resp_valid	(l2_resp_valid),
		     .l2_resp_error	(l2_resp_error),
		     .l2_resp_rdata	(l2_resp_rdata[63:0]),
		     .l2_inv_valid	(l2_inv_valid),
		     .l2_inv_addr	(l2_inv_addr[31:6]),
		     .l2_idle		(l2_idle),
		     .l2_bus_req	(l2_bus_req),
		     .l2_bus_cmd	(l2_bus_cmd[2:0]),
		     .l2_bus_tag	(l2_bus_tag[4:0]),
		     .l2_bus_addr	(l2_bus_addr[31:6]),
		     .l2_bus_data	(l2_bus_data[63:0]),
		     .l2_bus_hit	(l2_bus_hit),
		     .l2_bus_nack	(l2_bus_nack),
		     // Inputs
		     .clk		(clk),
		     .rst		(rst),
		     .resp_ready	(resp_ready),
		     .inv_ready		(inv_ready),
		     .bus_l2_grant	(bus_l2_grant),
		     .bus_valid		(bus_valid),
		     .bus_nack		(bus_nack),
		     .bus_cmd		(bus_cmd[2:0]),
		     .bus_tag		(bus_tag[4:0]),
		     .bus_addr		(bus_addr[31:6]),
		     .bus_data		(bus_data[63:0]));

  bfs_core bfs(
    /*AUTOINST*/
	       // Outputs
	       .bfs_csr_valid		(bfs_csr_valid),
	       .bfs_csr_error		(bfs_csr_error),
	       .bfs_csr_rdata		(bfs_csr_rdata[31:0]),
	       .bfs_dc_req		(bfs_dc_req),
	       .bfs_dc_op		(bfs_dc_op[1:0]),
	       .bfs_dc_addr		(bfs_dc_addr[31:0]),
	       .bfs_dc_wdata		(bfs_dc_wdata[63:0]),
	       // Inputs
	       .clk			(clk),
	       .rst			(rst),
	       .csr_bfs_valid		(csr_bfs_valid),
	       .csr_bfs_addr		(csr_bfs_addr[3:0]),
	       .csr_bfs_wen		(csr_bfs_wen),
	       .csr_bfs_wdata		(csr_bfs_wdata[31:0]),
	       .dc_ready		(dc_ready),
	       .dc_op			(dc_op[1:0]),
	       .dc_rbuf_empty		(dc_rbuf_empty),
	       .dc_valid		(dc_valid),
	       .dc_rdata		(dc_rdata[63:0]));

  l2 #(`BUSID_BFS) bfsl2(
    .req_valid(bfs_dc_req),
    .req_op(bfs_dc_op),
    .req_addr({bfs_dc_addr[31:6],4'd0}),
    .req_wmask(bfs_dc_op[1] ? 8'b00000001 : 8'b11111111),
    .req_wdata(bfs_dc_op[0] ? 64'h01 : bfs_dc_wdata),
    .l2_req_ready(dc_ready),
    .l2_resp_valid(dc_valid),
    .l2_resp_error(),
    .l2_resp_op(dc_op),
    .l2_resp_rdata(dc_rdata),
    .resp_ready(1'b1),
    .l2_inv_valid(),
    .l2_inv_addr(),
    .inv_ready(1'b1),
    .l2_idle(dc_rbuf_empty),
    .l2_bus_req(bfs_bus_req),
    .l2_bus_cmd(bfs_bus_cmd),
    .l2_bus_tag(bfs_bus_tag),
    .l2_bus_addr(bfs_bus_addr),
    .l2_bus_data(bfs_bus_data),
    .l2_bus_hit(bfs_bus_hit),
    .l2_bus_nack(bfs_bus_nack),
    .bus_l2_grant(bus_bfs_grant),
    /*AUTOINST*/
			 // Inputs
			 .clk			(clk),
			 .rst			(rst),
			 .bus_valid		(bus_valid),
			 .bus_nack		(bus_nack),
			 .bus_cmd		(bus_cmd[2:0]),
			 .bus_tag		(bus_tag[4:0]),
			 .bus_addr		(bus_addr[31:6]),
			 .bus_data		(bus_data[63:0]));

  dramctl dramctl(
    /*AUTOINST*/
		  // Outputs
		  .dramctl_bus_req	(dramctl_bus_req),
		  .dramctl_bus_cmd	(dramctl_bus_cmd[2:0]),
		  .dramctl_bus_tag	(dramctl_bus_tag[4:0]),
		  .dramctl_bus_addr	(dramctl_bus_addr[31:6]),
		  .dramctl_bus_data	(dramctl_bus_data[63:0]),
		  .dramctl_bus_nack	(dramctl_bus_nack),
		  // Inputs
		  .clk			(clk),
		  .rst			(rst),
		  .bus_valid		(bus_valid),
		  .bus_nack		(bus_nack),
		  .bus_hit		(bus_hit),
		  .bus_cmd		(bus_cmd[2:0]),
		  .bus_tag		(bus_tag[4:0]),
		  .bus_addr		(bus_addr[31:6]),
		  .bus_data		(bus_data[63:0]),
		  .bus_dramctl_grant	(bus_dramctl_grant));

  rom rom(
    /*AUTOINST*/
	  // Outputs
	  .rom_bus_req			(rom_bus_req),
	  .rom_bus_cmd			(rom_bus_cmd[2:0]),
	  .rom_bus_tag			(rom_bus_tag[4:0]),
	  .rom_bus_addr			(rom_bus_addr[31:6]),
	  .rom_bus_data			(rom_bus_data[63:0]),
	  .rom_bus_nack			(rom_bus_nack),
	  // Inputs
	  .clk				(clk),
	  .rst				(rst),
	  .bus_valid			(bus_valid),
	  .bus_nack			(bus_nack),
	  .bus_hit			(bus_hit),
	  .bus_cmd			(bus_cmd[2:0]),
	  .bus_tag			(bus_tag[4:0]),
	  .bus_addr			(bus_addr[31:6]),
	  .bus_data			(bus_data[63:0]),
	  .bus_rom_grant		(bus_rom_grant));

endmodule
