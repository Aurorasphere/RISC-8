use crate::{lexer::Token, encoder, error::AsmError};
use std::collections::HashMap;

pub struct FirstPassResult {
    pub symbols: HashMap<String, u16>, 
    pub items:   Vec<Item>, 
}

#[derive(Debug)]
pub enum Item {
    Inst(Vec<Token>),  // instr token
    Org(u16),          // .org <addr>
    Byte(u8),          // .byte <value>
    Ascii(String),     // .ascii "string"
    Label(String),     // <label>:
}

pub fn first_pass(tokens: &[Token]) -> Result<FirstPassResult, AsmError> {
    let mut pc: u16 = 0;
    let mut symbols = HashMap::<String, u16>::new();
    let mut items   = Vec::<Item>::new();

    let mut i = 0;
    while i < tokens.len() {
        match &tokens[i] {
            Token::Ident(name)
                if matches!(tokens.get(i + 1), Some(Token::Colon)) =>
            {
                if symbols.insert(name.clone(), pc).is_some() {
                    return Err(AsmError::DuplicateLabel(name.clone()));
                }
                items.push(Item::Label(name.clone()));
                i += 2;                     // Ident + Colon
            }

            Token::Dot => {
                let dir = match tokens.get(i + 1) {
                    Some(Token::Ident(s)) => s.as_str(),
                    _ => return Err(AsmError::Syntax(".<directive> expected".into())),
                };
                match dir {
                    "org" => {
                        if let Some(Token::Number(addr)) = tokens.get(i + 2) {
                            pc = *addr as u16;
                            items.push(Item::Org(pc));
                            i += 3;
                        } else {
                            return Err(AsmError::Syntax(".byte <number>".to_string()));
                        }
                    }
                    "byte" => {
                        if let Some(Token::Number(val)) = tokens.get(i + 2) {
                            items.push(Item::Byte(*val as u8));
                            pc = pc.checked_add(1).ok_or(AsmError::Overflow)?;
                            i += 3;
                        } else {
                            return Err(AsmError::Syntax(".byte <number>".to_string()));
                        }
                    }
                    "ascii" => {
                        if let Some(Token::String(s)) = tokens.get(i + 2) {
                            let len = s.len() as u16;
                            items.push(Item::Ascii(s.clone()));
                            pc = pc.checked_add(len).ok_or(AsmError::Overflow)?;
                            i += 3;
                        } else {
                            return Err(AsmError::Syntax(".ascii \"...\"".to_string()));
                        }
                    }
                    _ => return Err(AsmError::UnknownDirective(dir.into())),
                }
            }

            _ => {
                let inst = Vec::<Token>::new();
                if !inst.is_empty() {
                    items.push(Item::Inst(inst));
                    pc = pc.checked_add(2).ok_or(AsmError::Overflow)?; 
                }
                i += 1;
            }
        }
    }

    Ok(FirstPassResult { symbols, items })
}

pub fn second_pass(pass1: FirstPassResult) -> Result<(Vec<u8>, Vec<u8>), AsmError> {
    let mut code = Vec::<u8>::new();
    let mut data = Vec::<u8>::new();
    let mut pc: u16 = 0;

    for item in pass1.items {
        match item {
            Item::Inst(toks) => {
                let word = encoder::encode(&toks, &pass1.symbols)?;
                if pc as usize >= code.len() {
                    code.resize(pc as usize, 0);
                }
                code.extend_from_slice(&word.to_be_bytes()); 
                pc += 2;
            }

            Item::Org(addr) => {
                pc = addr;
                if pc as usize > code.len() {
                    code.resize(pc as usize, 0);
                }
            }

            Item::Byte(b)   => data.push(b),
            Item::Ascii(s)  => data.extend_from_slice(s.as_bytes()),

            Item::Label(_)  => {}
        }
    }

    Ok((data, code))
}

