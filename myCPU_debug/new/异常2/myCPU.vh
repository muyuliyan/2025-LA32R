`ifndef _myCPU_H
    `define _myCPU_H
    /* regcsr */
    `define CSR_CRMD   14'h000
    `define CSR_PRMD   14'h001
    // `define CSR_ECFG   14'h004
    `define CSR_ESTAT  14'h005
    `define CSR_ERA    14'h006
    // `define CSR_BADV   14'h007
    `define CSR_EENTRY 14'h00c
    `define CSR_SAVE0  14'h030
    `define CSR_SAVE1  14'h031
    `define CSR_SAVE2  14'h032
    `define CSR_SAVE3  14'h033
    // `define CSR_TID    14'h040
    // `define CSR_TCFG   14'h041
    // `define CSR_TVAL   14'h042
    // `define CSR_TICLR  14'h044

    `define CSR_CRMD_PLV    1:0
    `define CSR_CRMD_IE     2
    `define CSR_CRMD_DA     3
    `define CSR_CRMD_PG     4
    `define CSR_CRMD_DATF   6:5
    `define CSR_CRMD_DATM   8:7
    `define CSR_PRMD_PPLV   1:0
    `define CSR_PRMD_PIE    2
    `define CSR_ERA_PC      31:0
    `define CSR_ESTAT_ECODE 21:16
    `define CSR_ESTAT_ESUBC 30:22
    `define CSR_EENTRY_VA   31:6
    `define CSR_SAVE_DATA   31:0
    // `define CSR_TCFG_EN     0
    // `define CSR_TCFG_PER    1
    // `define CSR_TCFG_INITV  31:2
`endif