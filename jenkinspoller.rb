#!/usr/bin/env ruby

#
# Adapted from: http://isotope11.com/blog/monitoring-your-continuous-integration-server-with-traffic-lights-and-an-arduino
# 

require 'rubygems'
require 'serialport'
require 'json'
require 'net/http'

class JenkinsPoller

	def initialize(jenkins_url)
		@jenkins_url = jenkins_url
	end
	
	# check for arduino	
	def check_for_arduino()
	    if File.exist?("/dev/ttyACM0")
	    	@sp = SerialPort.new("/dev/ttyACM0", 9600)
	    elsif File.exist?("/dev/ttyUSB0")
	    	puts "* Found Arduino on /dev/ttyUSB0"
	    	@sp = SerialPort.new("/dev/ttyUSB0", 9600)
	    else
	    	abort("No Arduino present.")
    	end
	end
	
	# close the serial port
	def close
		@sp.close
	end
	
	# Safe http request
	def http_req(url)
		begin
			uri = URI.parse(url)
	        http = Net::HTTP.new(uri.host, uri.port)
	        request = Net::HTTP::Get.new(uri.request_uri)
	        return http.request(request)
		rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
       		abort("Could not access Jenkins server for: #{@jenkins_url}" + e)
       	end 
	end
	
	# Find and send job status
	def send_job_status(jobname)
		puts "* Checking status of: #{@jenkins_url}"
		response = http_req(@jenkins_url)
		
		jobs = JSON.parse(response.body)["jobs"]
		
		jobs.each { |j|
			name = j["name"]

			if name.casecmp(jobname) == 0
		    	write_serial_status(j)
   			end
		}
	end
	
	# Write the serial status to the serial device
	def write_serial_status(job)
    	project = job["name"]
    	
    	case job["color"]
			
			# TODO: Handle anime colors as well
						    	
    	    when "red"
    	       puts "Writing status for: #{project} [Failed]"
    	       @sp.write("3")
    	    
    	    when "yellow"
		   		puts "Writing status for: #{project} [Unstable]"
		   		@sp.write("1")
		   		
    	    when "blue"
    	       puts "Writing status for: #{project} [Success]"
    	       @sp.write("4")
    	    else 
   				puts "Unknown color: #{job["color"]}" 	    
    	end
	end
end

poller = JenkinsPoller.new("http://myjenkinserver:8080/jenkins/api/json")
poller.check_for_arduino()
loop do
	begin
		poller.send_job_status("myprojectname")
		sleep(5)
	rescue Exception => e
		puts "Could not send job status to Arduino"
	ensure
		poller.close()
	end
end

