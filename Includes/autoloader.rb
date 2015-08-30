 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
 # 															 #
 # Ruby Minimizer for CSS and JS files v1.0.0				 #
 # http://www.pedrojhenriques.com 							 #
 # 															 #
 # Copyright 2015, PedroHenriques 							 #
 # Free to use under the MIT license.			 			 #
 # http://www.opensource.org/licenses/mit-license.php 		 #
 # 															 #
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# load classes
dir = Dir.new("#{File.dirname(File.dirname(__FILE__))}/Classes")
dir.each do |file|
	if file.match(/^(.|..)$/)
		next
	end

	require "#{File.dirname(File.dirname(__FILE__))}/Classes/#{file}"
end
dir.close