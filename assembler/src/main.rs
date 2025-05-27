//! assembler – RISC-8 16-bit ISA two-pass assembler (CLI)

use anyhow::Result;
use clap::Parser;
use logos::Logos;           // Token::lexer()
use std::{fs, fs::File, io::Write, path::Path};

mod lexer;
mod parser;
mod encoder;
mod error;

use lexer::Token;

/// CLI 옵션 정의
#[derive(Parser, Debug)]
#[command(author, version, about = "RISC-8 Assembler")]
struct Cli {
    /// 입력 ASM 소스
    input: String,

    /// 출력 BIN 파일 (기본 = program.bin)
    #[arg(short, long, default_value = "program.bin")]
    output: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    /* 1️⃣  소스 파일 읽기 */
    let src = fs::read_to_string(&cli.input)?;
    println!("📄  Assemble {}", cli.input);

    /* 2️⃣  토큰화 (Logos 0.13 ⇒ Iterator<Item = Result<Token, ()>>) */
    let tokens: Vec<Token> = Token::lexer(&src)
        .filter_map(Result::ok)   // 오류 토큰은 건너뜀
        .collect();

    /* 3️⃣  1-패스 · 2-패스 */
    let pass1             = parser::first_pass(&tokens)?;
    let (data, code)      = parser::second_pass(pass1)?;

    /* 4️⃣  program.bin 생성 (4-바이트 little-endian 헤더 = data 길이) */
    write_bin(&cli.output, &data, &code)?;
    println!(
        "✅  OK  data:{:>4}B  code:{:>4}B  →  {}",
        data.len(),
        code.len(),
        cli.output
    );
    Ok(())
}

/// data + code 를 BIN 파일로 저장
fn write_bin<P: AsRef<Path>>(path: P, data: &[u8], code: &[u8]) -> Result<()> {
    let mut f = File::create(path)?;
    /* header: data size (u32 LE) */
    f.write_all(&(data.len() as u32).to_le_bytes())?;
    f.write_all(data)?;
    f.write_all(code)?;
    Ok(())
}

