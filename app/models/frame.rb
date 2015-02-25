class Frame < ActiveRecord::Base
	belongs_to :game

  # returns a relative frame to the current one
  def getFrame(frames_to_shift)
    adjustment_for_frame_indexing = 1
    game.frames[game.current_frame + frames_to_shift - adjustment_for_frame_indexing]
  end

  # increments a frame's score
  def updateScore(score)
    self.frame_score += score
    self.save
  end

  def setScore(bowled_pins)
    self.updateScore(bowled_pins)

    # Handle 2 strikes in a row
    if getFrame(-1).isStrike? and getFrame(-2).isStrike?

      # First stroke of current frame
    	if second_stroke.nil?
      	getFrame(-2).updateScore(bowled_pins)
      end

      # Second stroke of current frame
      if extra_stroke.nil?
       getFrame(-1).updateScore(bowled_pins)
     	end

    # Handle strike in previous frame on completion of current frame
    elsif getFrame(-1).isStrike? and extra_stroke.nil?
      getFrame(-1).updateScore(bowled_pins)

    # Handle spare in previous frame after first stroke of current frame
    elsif getFrame(-1).isSpare? and second_stroke.nil?
      getFrame(-1).updateScore(bowled_pins)
    end
  end

  def isStrike?
    # Handle strike in first stroke of frames 1 through 10
    if second_stroke.nil?
      self.first_stroke == "X"

    # Handle strike in second stroke of frame 10
    elsif extra_stroke.nil?
      self.second_stroke == "X"

    # Handle strike in extra stroke of frame 10
    else 
      self.extra_stroke == "X"
    end
  end

  def isSpare?
    # Handle spare in frames 1 through 10
    if extra_stroke.nil?
      self.second_stroke == "/"

    # Handle spare in extra stroke of frame 10
    else
      self.extra_stroke == "/"
    end
  end
end
