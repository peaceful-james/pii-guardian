defmodule PiiGuardian.AnthropicPiiDetectionTest do
  use PiiGuardian.DataCase, async: true

  alias PiiGuardian.AnthropicPiiDetection

  describe "text_contains_pii?/1" do
    test "returns true for text containing PII" do
      text = File.read!("test/support/unsafe_pii.txt")
      assert {:unsafe, explanation} = AnthropicPiiDetection.detect_pii_in_text(text)
      assert String.contains?(explanation, "Passport")
    end

    test "returns false for text without PII" do
      text = File.read!("test/support/safe.txt")
      assert AnthropicPiiDetection.detect_pii_in_text(text) == :safe
    end
  end
end
