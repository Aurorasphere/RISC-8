use crate::{lexer::Token, error::AsmError};
use std::collections::HashMap;

pub type SymTab = HashMap<String, u16>;

fn reg_code(tok: &Token) -> Result<u8, AsmError> {
    match tok {
        Token::Reg(s) if s == "A"  => Ok(0),
        Token::Reg(s) if s == "B"  => Ok(1),
        Token::Reg(s) if s == "C"  => Ok(2),
        Token::Reg(s) if s == "D"  => Ok(3),
        Token::Reg(s) if s == "E"  => Ok(4),
        Token::Reg(s) if s == "SP" => Ok(5),
        Token::Reg(s) if s == "AH" => Ok(6),
        Token::Reg(s) if s == "AL" => Ok(7),
        _ => Err(AsmError::Syntax("register expected".to_string())),
    }
}

fn parse_imm(tok: &Token, sym: &SymTab) -> Result<i32, AsmError> {
    match tok {
        Token::Number(n)   => Ok(*n as i32),
        Token::Ident(name) => sym
            .get(name)
            .map(|v| *v as i32)
            .ok_or_else(|| AsmError::UnknownSymbol(name.clone())),
        _ => Err(AsmError::Syntax("immediate/label expected".into())),
    }
}

fn imm7_bits(val: i32) -> Result<u16, AsmError> {
    if val < -64 || val > 63 {
        return Err(AsmError::Range("imm7 out of range (-64..63)".into()));
    }
    Ok(((val as i16) & 0x7F) as u16) // 하위 7비트
}

const OPC_R:   u16 = 0b000;
const OPC_I:   u16 = 0b001;
const OPC_MEM: u16 = 0b101;
const OPC_J:   u16 = 0b010;
const OPC_T:   u16 = 0b011;

fn enc_r(fn4: u8, fn3: u8, rd: u8, rn: u8) -> u16 {
      ((fn4 as u16) << 12)
    | ((rn  as u16) <<  9)
    | ((rd  as u16) <<  6)
    | ((fn3 as u16) <<  3)
    | OPC_R
}

fn enc_i(fn3: u8, rd: u8, imm: i32, sym: &SymTab) -> Result<u16, AsmError> {
    let imm7 = imm7_bits(imm)?;
    Ok( (imm7 << 9)
       | ((rd  as u16) << 6)
       | ((fn3 as u16) << 3)
       | OPC_I )
}

fn enc_mem(fn3: u8, r: u8) -> u16 {
      ((r   as u16) << 6)
    | ((fn3 as u16) << 3)
    | OPC_MEM
}

#[inline] fn enc_j(fn3: u8) -> u16 { ((fn3 as u16) << 3) | OPC_J }

fn enc_t(fn3: u8, r: u8) -> u16 {
      ((r as u16) << 6)
    | ((fn3 as u16) << 3)
    | OPC_T
}

fn enc_t_int(n: i32) -> Result<u16, AsmError> {
    if !(0..=15).contains(&n) {
        return Err(AsmError::Range("intnum 0‥15".into()));
    }
    Ok(((n as u16) << 6) | ((0b010 as u16) << 3) | OPC_T)
}

pub fn encode(toks: &[Token], sym: &SymTab) -> Result<u16, AsmError> {
    use Token::*;
    match toks {
        [Add, rd, Comma, rn] => Ok(enc_r(0b0000, 0b000, reg_code(rd)?, reg_code(rn)?)),
        [Sub, rd, Comma, rn] => Ok(enc_r(0b1000, 0b000, reg_code(rd)?, reg_code(rn)?)),
        [Or,  rd, Comma, rn] => Ok(enc_r(0b0000, 0b001, reg_code(rd)?, reg_code(rn)?)),
        [And, rd, Comma, rn] => Ok(enc_r(0b0000, 0b010, reg_code(rd)?, reg_code(rn)?)),
        [Xor, rd, Comma, rn] => Ok(enc_r(0b0000, 0b011, reg_code(rd)?, reg_code(rn)?)),
        [Lsl, rd, Comma, rn] => Ok(enc_r(0b0000, 0b100, reg_code(rd)?, reg_code(rn)?)),
        [Lsr, rd, Comma, rn] => Ok(enc_r(0b0000, 0b101, reg_code(rd)?, reg_code(rn)?)),
        [Asr, rd, Comma, rn] => Ok(enc_r(0b1000, 0b101, reg_code(rd)?, reg_code(rn)?)),
        [Cmp, rd, Comma, rn] => Ok(enc_r(0b0000, 0b110, reg_code(rd)?, reg_code(rn)?)),
        
        [Addi, rd, Comma, Hash, imm] => enc_i(0b000, reg_code(rd)?, parse_imm(imm, sym)?, sym),
        [Ori,  rd, Comma, Hash, imm] => enc_i(0b001, reg_code(rd)?, parse_imm(imm, sym)?, sym),
        [Andi, rd, Comma, Hash, imm] => enc_i(0b010, reg_code(rd)?, parse_imm(imm, sym)?, sym),
        [Xori, rd, Comma, Hash, imm] => enc_i(0b011, reg_code(rd)?, parse_imm(imm, sym)?, sym),
        [Lsli, rd, Comma, Hash, imm] => enc_i(0b100, reg_code(rd)?, parse_imm(imm, sym)?, sym),
        [Lsri, rd, Comma, Hash, imm] => enc_i(0b101, reg_code(rd)?, parse_imm(imm, sym)?, sym),
        [Cmpi, rd, Comma, Hash, imm] => enc_i(0b110, reg_code(rd)?, parse_imm(imm, sym)?, sym),

        [Ld, rd]          => Ok(enc_mem(0b000, reg_code(rd)?)),
        [St, rm]          => Ok(enc_mem(0b001, reg_code(rm)?)),

        [Jmp]  => Ok(enc_j(0b000)),
        [Jeq]  => Ok(enc_j(0b001)),
        [Jneq] => Ok(enc_j(0b010)),
        [Jgt]  => Ok(enc_j(0b011)),
        [Jlt]  => Ok(enc_j(0b100)),
        [Jegt] => Ok(enc_j(0b101)),
        [Jelt] => Ok(enc_j(0b110)),

        [Push, rm]            => Ok(enc_t(0b000, reg_code(rm)?)),
        [Pop,  rd]            => Ok(enc_t(0b001, reg_code(rd)?)),
        [Int,  Hash, num]     => enc_t_int(parse_imm(num, sym)?),
        [Ret]                 => Ok(enc_t(0b011, 0)),
        [Halt]                => Ok(0xFFFF),

        _ => Err(AsmError::UnsupportedInst),
    }
}
