// errors.mbt
//
// 编码错误类型：非法参数/输入以结构化错误拒绝（绝不 panic），
// CLI 与消费方按 to_message 渲染。

///|
/// 编码参数或输入非法时 raise 的错误。
pub(all) suberror EncodeError {
  InvalidBitsPerSample
  InvalidChannels
  InvalidSampleRate
  InvalidBlockSize
  InvalidInputSize
}

///|
/// 面向使用者的错误描述。
pub fn EncodeError::to_message(self : EncodeError) -> String {
  match self {
    InvalidBitsPerSample => "invalid bits per sample (must be 8/16/24/32)"
    InvalidChannels => "invalid channel count (must be 1-8)"
    InvalidSampleRate => "invalid sample rate (must be 1..=655350 Hz)"
    InvalidBlockSize => "invalid block size (must be 16..=65535)"
    InvalidInputSize => "input size is not divisible by channels * (bps/8)"
  }
}
