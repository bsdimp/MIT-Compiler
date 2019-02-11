/* dispatch numbers for 68000 instructions.  These numbers are placed in
 * the code_i component of each instruction bucket by init.c and are used
 * by ins.c for dispatching.
 */

#define i_abcd	1
#define i_addb	2
#define i_addw	3
#define i_addl	4
/* adda */
/* addi */
#define i_addqb	5
#define i_addqw	6
#define i_addql	7
#define i_addxb	8
#define i_addxw	9
#define i_addxl	10
#define i_andb	11
#define i_andw	12
#define i_andl	13
/* andi */
#define i_aslb	14
#define i_aslw	15
#define i_asll	16
#define i_asrb	17
#define i_asrw	18
#define i_asrl	19
#define i_bcc	20
#define i_bccs	21
#define i_bchg	22
#define i_bclr	23
#define i_bcs	24
#define i_bcss	25
#define i_beq	26
#define i_beqs	27
#define i_bge	28
#define i_bges	29
#define i_bgt	30
#define i_bgts	31
#define i_bhi	32
#define i_bhis	33
#define i_ble	34
#define i_bles	35
#define i_bls	36
#define i_blss	37
#define i_blt	38
#define i_blts	39
#define i_bmi	40
#define i_bmis	41
#define i_bne	42
#define i_bnes	43
#define i_bpl	44
#define i_bpls	45
#define i_bra	46
#define i_bras	47
#define i_bset	48
/* bset.s */
#define i_bsr	49
#define i_bsrs	50
#define i_btst	51
/* btst.l */
#define i_bvc	52
#define i_bvcs	53
#define i_bvs	54
#define i_bvss	55
#define i_chk	56
#define i_clrb	57
#define i_clrw	58
#define i_clrl	59
#define i_cmpb	60
#define i_cmpw	61
#define i_cmpl	62
/* cmpa */
/* cmpi */
#define i_cmpmb	63
#define i_cmpmw	64
#define i_cmpml	65
#define i_dbcc	66
#define i_dbcs	67
#define i_dbeq	68
#define i_dbf	69
#define i_dbra	70
#define i_dbge	71
#define i_dbgt	72
#define i_dbhi	73
#define i_dble	74
#define i_dbls	75
#define i_dblt	76
#define i_dbmi	77
#define i_dbne	78
#define i_dbpl	79
#define i_dbt	80
#define i_dbvc	81
#define i_dbvs	82
#define i_divs	83
#define i_divu	84
#define i_eorb	85
#define i_eorw	86
#define i_eorl	87
/* eori */
#define i_exg	88
#define i_extw	89
#define i_extl	90
#define i_jbsr	91
#define i_jcc	92
#define i_jcs	93
#define i_jeq	94
#define i_jge	95
#define i_jgt	96
#define i_jhi	97
#define i_jle	98
#define i_jls	99
#define i_jlt	100
#define i_jmi	101
#define i_jmp	102
#define i_jne	103
#define i_jpl	104
#define i_jra	105
#define i_jsr	106
#define i_jvc	107
#define i_jvs	108
#define i_lea	109
#define i_link	110
#define i_lslb	111
#define i_lslw	112
#define i_lsll	113
#define i_lsrb	114
#define i_lsrw	115
#define i_lsrl	116
#define i_movb	117
#define i_movw	118
#define i_movl	119
/* move for move sr, move cc, etc */
#define i_movemw	120
#define i_moveml	121
#define i_movepw	122
#define i_movepl	123
#define i_moveq	124
#define i_muls	125
#define i_mulu	126
#define i_nbcd	127
#define i_negb	128
#define i_negw	129
#define i_negl	130
#define i_negxb	131
#define i_negxw	132
#define i_negxl	133
#define i_nop	134
#define i_notb	135
#define i_notw	136
#define i_notl	137
#define i_orb	138
#define i_orw	139
#define i_orl	140
#define i_orib	141
#define i_oriw	142
#define i_oril	143
#define i_pea	144
#define i_reset	145
#define i_rolb	146
#define i_rolw	147
#define i_roll	148
#define i_rorb	149
#define i_rorw	150
#define i_rorl	151
#define i_roxlb	152
#define i_roxlw	153
#define i_roxll	154
#define i_roxrb	155
#define i_roxrw	156
#define i_roxrl	157
#define i_rte	158
#define i_rtr	159
#define i_rts	160
#define i_sbcd	161
#define i_scc	162
#define i_scs	163
#define i_seq	164
#define i_sf	165
#define i_sge	166
#define i_sgt	167
#define i_shi	168
#define i_sle	169
#define i_sls	170
#define i_slt	171
#define i_smi	172
#define i_sne	173
#define i_spl	174
#define i_st	175
#define i_stop	176
#define i_subb	177
#define i_subw	178
#define i_subl	179
#define i_subqb	180
#define i_subqw	181
#define i_subql	182
#define i_subxb	183
#define i_subxw	184
#define i_subxl	185
#define i_svc	186
#define i_svs	187
#define i_swap	188
#define i_tas	189
#define i_trap	190
#define i_trapv	191
#define i_tstb	192
#define i_tstw	193
#define i_tstl	194
#define i_unlk	195

#define i_long	196
#define i_word	197
#define i_byte	198
#define i_text	199
#define i_data	200
#define i_bss	201
#define i_globl 202
#define i_comm	203
#define i_even	204
#define i_ascii 205
#define i_asciz 206
#define i_align 207

#define i_addib 212
#define i_addiw 213
#define i_addil	214
#define i_andib 215
#define i_andiw 216
#define i_andil 217

#define i_bsets 220
#define i_btstl 221
#define i_cmpib 224
#define i_cmpiw 225
#define i_cmpil 226
#define i_eorib 227
#define i_eoriw 228
#define i_eoril 229

/*    #define i_move 	230   --- never used --- ANNY      */

#define i_subib 240
#define i_subiw 241
#define i_subil 242

#define i_equal 245
#define i_dcb	246
#define	i_dcw	247
#define i_dcl	248
#define i_refa	249
#define i_refr	250
#define i_include 251
#define i_null	300
