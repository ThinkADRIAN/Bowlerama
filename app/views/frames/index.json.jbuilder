json.array!(@frames) do |frame|
  json.extract! frame, :id, :first_stroke, :second_stroke, :extra_stroke, :frame_score, :frame_number
  json.url frame_url(frame, format: :json)
end
