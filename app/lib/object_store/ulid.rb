# frozen_string_literal: true

module ObjectStore
  # コメントのファイル名に使う ULID（時刻順にソートできる 26 文字の ID）。gem を増やさないための最小実装。
  # 同じミリ秒内では乱数部をインクリメントして単調増加にする（同一プロセス内でのコメント順を保証する）
  module Ulid
    ENCODING = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    MUTEX = Mutex.new
    @last_ms = nil
    @last_random = nil

    def self.generate(time: Time.now)
      ms = (time.to_f * 1000).to_i
      random = MUTEX.synchronize do
        if @last_ms == ms && @last_random
          @last_random += 1
        else
          @last_ms = ms
          @last_random = SecureRandom.random_number(2**80)
        end
        @last_random
      end
      encode(ms, 10) + encode(random, 16)
    end

    def self.encode(value, length)
      out = String.new
      length.times { out.prepend(ENCODING[value & 31]); value >>= 5 }
      out
    end
    private_class_method :encode
  end
end
