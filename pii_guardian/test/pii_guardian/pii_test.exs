defmodule PIIGuardian.PIITest do
  use ExUnit.Case, async: true
  
  alias PIIGuardian.PII.Analyzer
  alias PIIGuardian.PII.TextDetector
  alias PIIGuardian.PII.ImageDetector
  alias PIIGuardian.PII.PDFDetector
  
  describe "TextDetector" do
    test "detect_pii/1 identifies email addresses" do
      text = "Please contact me at john.doe@example.com"
      
      # This test assumes the AI service is in test mode
      assert {:pii_found, %{types: types}} = TextDetector.detect_pii(text)
      assert "Email" in types
    end
    
    test "detect_pii/1 identifies phone numbers" do
      text = "Call me at 555-123-4567"
      
      assert {:pii_found, %{types: types}} = TextDetector.detect_pii(text)
      assert "Phone Number" in types
    end
    
    test "detect_pii/1 returns no_pii for safe text" do
      text = "This text has no PII information in it."
      
      assert {:no_pii} = TextDetector.detect_pii(text)
    end
    
    test "detect_pii_with_regex/1 identifies email addresses" do
      text = "Please contact me at john.doe@example.com"
      
      assert {:pii_found, %{types: types}} = TextDetector.detect_pii_with_regex(text)
      assert "Email" in types
    end
  end
  
  describe "Analyzer" do
    test "analyze_content/1 detects PII in text content" do
      content = %{
        text: "My email is jane.doe@example.com and my phone is 555-987-6543"
      }
      
      assert {:pii_found, %{types: types}} = Analyzer.analyze_content(content)
      assert "Email" in types
      assert "Phone Number" in types
    end
    
    test "analyze_content/1 detects PII in Notion-like content" do
      content = %{
        title: "Contact Information",
        properties: [
          {"Name", "Jane Doe"},
          {"Email", "jane.doe@example.com"},
          {"Phone", "555-987-6543"}
        ]
      }
      
      assert {:pii_found, %{types: types}} = Analyzer.analyze_content(content)
      assert "Email" in types
      assert "Phone Number" in types
    end
    
    test "analyze_content/1 returns no_pii for safe content" do
      content = %{
        text: "This text has no PII information in it."
      }
      
      assert {:no_pii} = Analyzer.analyze_content(content)
    end
  end
end