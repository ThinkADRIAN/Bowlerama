class Game < ActiveRecord::Base
	has_many :frames
	accepts_nested_attributes_for :frames
end
