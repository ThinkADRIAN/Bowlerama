class Game < ActiveRecord::Base
	has_many :frames, :dependent => :destroy
	accepts_nested_attributes_for :frames
end
