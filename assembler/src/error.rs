use thiserror::Error;

#[derive(Debug, Error)]
pub enum AsmError {
    #[error("syntax error: {0}")]
    Syntax(String),

    #[error("unknown directive: {0}")]
    UnknownDirective(String),

    #[error("unsupported instruction")]
    UnsupportedInst,

    #[error("duplicate label: `{0}`")]
    DuplicateLabel(String),

    #[error("unknown symbol: `{0}`")]
    UnknownSymbol(String),

    #[error("value out of range: {0}")]
    Range(String),

    #[error("unexpected end of file")]
    UnexpectedEof,

    #[error("address/size overflow")]
    Overflow,
}

