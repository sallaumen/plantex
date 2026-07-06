defmodule Core.PhotoTest do
  use ExUnit.Case, async: true
  alias Core.Photo

  test "constrói metadados de foto" do
    p = %Photo{
      station_id: "st1",
      captured_at: 1_720_000_000_000,
      content_type: "image/jpeg",
      width: 1920,
      height: 1080,
      byte_size: 204_800
    }

    assert p.content_type == "image/jpeg"
    assert p.width == 1920
  end
end
