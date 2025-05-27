use logos::Logos;

#[derive(Logos, Debug, PartialEq, Clone)]
pub enum Token {
    // ── R-Type ────────────────────────────────
    #[token("add")] Add,
    #[token("sub")] Sub,
    #[token("or")]  Or,
    #[token("and")] And,
    #[token("xor")] Xor,
    #[token("lsl")] Lsl,
    #[token("lsr")] Lsr,
    #[token("asr")] Asr,
    #[token("cmp")] Cmp,

    // ── I-Type ────────────────────────────────
    #[token("addi")] Addi,
    #[token("ori")]  Ori,
    #[token("andi")] Andi,
    #[token("xori")] Xori,
    #[token("lsli")] Lsli,
    #[token("lsri")] Lsri,
    #[token("cmpi")] Cmpi,
    #[token("ld")]   Ld,
    #[token("st")]   St,

    // ── J-Type ────────────────────────────────
    #[token("jmp")]  Jmp,
    #[token("jeq")]  Jeq,
    #[token("jneq")] Jneq,
    #[token("jgt")]  Jgt,
    #[token("jlt")]  Jlt,
    #[token("jegt")] Jegt,
    #[token("jelt")] Jelt,

    // ── T-Type ────────────────────────────────
    #[token("push")] Push,
    #[token("pop")]  Pop,
    #[token("int")]  Int,
    #[token("ret")]  Ret,
    #[token("halt")] Halt,

    // ── Registers ─────────────────────────────
    #[regex(r"(A|B|C|D|E|SP|AH|AL)", |lex| lex.slice().to_string())]
    Reg(String),
    
    // ── Ident / Label ────────────────────────
    #[regex(r"[A-Za-z_][A-Za-z0-9_]*", |lex| lex.slice().to_string())]
    Ident(String),

    // ── Numbers ──────────────────────────────
    #[regex(r"0x[0-9A-Fa-f]+", |lex| u32::from_str_radix(&lex.slice()[2..],16).unwrap())]
    #[regex(r"0b[01]+",         |lex| u32::from_str_radix(&lex.slice()[2..],2).unwrap())]
    #[regex(r"[0-9]+", |lex| lex.slice().parse::<u32>().unwrap())]
    Number(u32),
    
    // ── Strings ──────────────────────────────
    #[regex(r#""([^"\\]|\\.)*""#, |lex| lex.slice()[1..lex.slice().len()-1].to_string())]
    String(String),

    // Symbols , : # .
    #[token(",")] Comma,
    #[token(":")] Colon,
    #[token("#")] Hash,
    #[token(".")] Dot,

    // Skip
    // #[regex(r";[^\n]*", logos::skip)]
    // #[regex(r"[ \t\r\n\f]+", logos::skip)]
}

