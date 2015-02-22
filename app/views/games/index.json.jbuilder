json.array!(@games) do |game|
  json.extract! game, :id, :current_frame, :frame_stroke, :total_score
  json.url game_url(game, format: :json)
end
