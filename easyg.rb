#!/usr/bin/env ruby
#https://github.com/seeu-inspace/easyg/blob/main/easyg.rb
#tools used: amass, subfinder, github-subdomains, gobuster, anew, httprobe, naabu

require 'uri'
require 'net/http'
require 'json'
require 'socket'


puts "\e[36m\n 
███████╗ █████╗ ███████╗██╗   ██╗ ██████╗    ██████╗ ██████╗ 
██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝██╔════╝    ██╔══██╗██╔══██╗
█████╗  ███████║███████╗ ╚████╔╝ ██║  ███╗   ██████╔╝██████╔╝
██╔══╝  ██╔══██║╚════██║  ╚██╔╝  ██║   ██║   ██╔══██╗██╔══██╗
███████╗██║  ██║███████║   ██║   ╚██████╔╝██╗██║  ██║██████╔╝
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝╚═╝  ╚═╝╚═════╝ 
                   Made with <3 by Riccardo Malatesta (@seeu)
\n\e[0m"



def adding_anew(file_tmp,file_final)
	system "type " + file_tmp.gsub('/','\\') + " | anew " + file_final
	File.delete(file_tmp) if File.exists? file_tmp
end


def delete_if_empty(file)

	if File.zero?(file)
		puts "[\e[36m+\e[0m] No result found"
		File.delete(file) if File.exists?(file)
	else
		puts "[\e[36m+\e[0m] Results added at " + file
	end
	
end

def request_fun(uri)
	
	proxy_host = '127.0.0.1'
	proxy_port = '8080'
	
	headers = {
		"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:106.0) Gecko/20100101 Firefox/106.0",
		"Cookie": "0=1"
	}
	
	ssl_options = {
		:use_ssl => true,
		:verify_mode => OpenSSL::SSL::VERIFY_NONE
	}

	res = nil
	req = Net::HTTP::Get.new(uri.request_uri, headers)
	
	Net::HTTP.start(uri.host, uri.port, proxy_host, proxy_port, ssl_options) do |http|
		res = http.request(req)
	end

	return res

end


if ARGV[1] == "firefox"

	i = 0

	File.open(ARGV[0],'r').each_line do |f|
	
		target = f.gsub("\n","").to_s
		
		i += 1
	
		puts "[\e[36m#{i.to_s}\e[0m] Firefox open > " + target
		system 'start firefox "' + target + '"'
				
		sleep 30 if i%20==0
		
	end

end


if ARGV[1] == "gettoburp"
	
	i = 0
	
	File.open(ARGV[0],'r').each_line do |f|
		begin
		
			redirect = 2
		
			res = request_fun(URI.parse(f.gsub("\n","").to_s))
			
			puts "[\e[36m#{i.to_s}\e[0m] GET > " + f.gsub("\n","").to_s
			i += 1
			
			while res.is_a?(Net::HTTPRedirection) && redirect > 0
				puts "    Redirecting to > " + res['location'].to_s
				res = request_fun(URI.parse(res['location']))
				redirect -= 1
			end

		rescue Exception => e
			puts "[\e[31m+\e[0m] ERROR: " + e.message
		end
	end

end


if ARGV[1] == "assetenum"

	system "mkdir output" if File.directory?('output') == false
	
	File.open(ARGV[0],'r').each_line do |f|
	
		target = f.gsub("\n","").to_s
		
		#== amass ==
		puts "\n[\e[36m+\e[0m] Enumerating subdomains for " + target + " with amass"
		system "amass enum -brute -active -d " + target + " -o output/" + target + "_tmp.txt -v"

		#== subfinder ==
		puts "\n[\e[36m+\e[0m] Enumerating subdomains for " + target + " with subfinder"
		system "subfinder -d " + target + " -all -o output/" + target + "_subfinder.txt"
		
		adding_anew("output/" + target + "_subfinder.txt", "output/" + target + "_tmp.txt")
		
		#== github-subdomains ==
		puts "\n[\e[36m+\e[0m] Enumerating subdomains for " + target + " with github-subdomains"
		system "github-subdomains -t %GITHUB_TOKEN% -d " + target + " -o output/" + target + "_github.txt"
		
		adding_anew("output/" + target + "_github.txt", "output/" + target + "_tmp.txt")
		
		#== crt.sh ==
		puts "\n[\e[36m+\e[0m] Enumerating subdomains for " + target + " with crt.sh"
		
		begin
			uri = URI.parse("https://crt.sh/?q=" + target + "&output=json")
			response = Net::HTTP.get_response(uri)
			crtsh = JSON.parse((response.body).to_s)

			crtsh_o = File.new("output/" + target + "_crtsh.txt", "w")

			crtsh.each do | f |
				puts f["common_name"].gsub('*.','').to_s
				if f.include? "." + target
					crtsh_o.puts f["common_name"].gsub('*.','').to_s
				end
			end

			crtsh_o.close unless crtsh_o.nil? or crtsh_o.closed?
			
			adding_anew("output/" + target + "_crtsh.txt", "output/" + target + "_tmp.txt")
			
		rescue Exception => e
			puts "[\e[31m+\e[0m] ERROR: " + e.message
		end
		
		#== gobuster ==
		
		if ARGV[2] == "gb"
		
			if !File.exists? "all.txt"
				uri = URI.parse("https://gist.githubusercontent.com/jhaddix/86a06c5dc309d08580a018c66354a056/raw/96f4e51d96b2203f19f6381c8c545b278eaa0837/all.txt")
				response = Net::HTTP.get_response(uri)
				alltxt = (response.body).to_s
				File.open('all.txt', 'w') { |file| file.write(alltxt) }
			end
		
			puts "\n[\e[34m+\e[0m] Enumerating subdomains for " + target + " with gobuster and all.txt"
			system "gobuster dns -d " + target + " -v -t 250 --no-color --wildcard -o output/" + target + "_gobuster_tmp.txt -w all.txt"

			gobuster_o = File.new("output/" + target + "_gobuster.txt", 'w')
			gobuster_tmp = File.open("output/" + target + "_gobuster_tmp.txt",'r')

			gobuster_tmp.each_line do |f|
				if f.include? "Found: "
					gobuster_o.puts f.gsub("Found: ","")
				end
			end

			gobuster_tmp.close unless gobuster_tmp.nil? or gobuster_tmp.closed?
			File.delete("output/" + target + "_gobuster_tmp.txt") if File.exists? "output/" + target + "_gobuster_tmp.txt"
			
			gobuster_o.close unless gobuster_o.nil? or gobuster_o.closed?
			adding_anew("output/" + target + "_gobuster.txt", "output/" + target + "_tmp.txt")

		end
		
		#== anew final ==
		
		puts "\n[\e[36m+\e[0m] Checking if IPs for the subdomains of " + target + " exist"
		
		allsubs_final = File.new("output/" + target + ".txt", 'w')
		allsubs_tmp = File.open("output/" + target + "_tmp.txt",'r')

		allsubs_tmp.each_line do |line|
			begin
				ip=IPSocket::getaddress(line.strip)
			rescue
				ip="unknown"
			end

			if ip!="unknown"
				puts line
				allsubs_final.puts line
			end
			
		end

		allsubs_tmp.close unless allsubs_tmp.nil? or allsubs_tmp.closed?
		File.delete("output/" + target + "_tmp.txt") if File.exists? "output/" + target + "_tmp.txt"
		allsubs_final.close unless allsubs_final.nil? or allsubs_final.closed?

		puts "[\e[36m+\e[0m] Results for " + target + " saved as output/" + target + ".txt"
		
		puts "\n[\e[36m+\e[0m] Adding the results for " + target + " to output/allsubs_" + ARGV[0]
		system "type output\\" + target + ".txt | anew output/allsubs_" + ARGV[0]
		puts "[\e[36m+\e[0m] Results for " + ARGV[0] + " saved as output/allsubs_" + ARGV[0]

	end
	
	#== httprobe ==
	puts "[\e[36m+\e[0m] Checking output/allsubs_" + ARGV[0] + " with httprobe"
	system "type output\\allsubs_" + ARGV[0] + " | httprobe -p http:81 -p http:3000 -p https:3000 -p http:3001 -p https:3001 -p http:8000 -p http:8080 -p https:8443 -c 150 > output/httprobe_" + ARGV[0] + " && type output\\httprobe_" + ARGV[0]
	puts "[\e[36m+\e[0m] Results saved as output/httprobe_" + ARGV[0]
	
	#== naabu ==
	puts "[\e[36m+\e[0m] Searching for more open ports in output/allsubs_" + ARGV[0] + " with naabu"
	system "naabu -v -list output/allsubs_" + ARGV[0] + " -exclude-ports 80,443,81,3000,3001,8000,8080,8443 -c 1000 -rate 7000 -stats -o output/naabu_" + ARGV[0]
	delete_if_empty "output/naabu_" + ARGV[0]
	
	#== naabu | httprobe ==
	if File.exists? "output/naabu_" + ARGV[0]
		puts "[\e[36m+\e[0m] Checking for hidden web ports in output/naabu_" + ARGV[0]
		system "type output\\naabu_" + ARGV[0] + " | httprobe > output/httprobe_naabu_" + ARGV[0]
		
		if File.exists? "output/httprobe_naabu_" + ARGV[0]
			system "type output\\httprobe_naabu_" + ARGV[0]
			adding_anew("output/httprobe_naabu_" + ARGV[0], "output/httprobe_" + ARGV[0])
			puts "[\e[36m+\e[0m] Results added at output/httprobe_" + ARGV[0]
		end
	end
	
end


if ARGV[0] == "help"

	puts "Usage: ruby easyg.rb <file_input> <option> \n\n"
	
	puts "Options"
	puts "	firefox					open every entry in <file_input> with firefox"
	puts "	gettoburp				for every entry in <file_input> send a GET request"
	puts "	assetenum				asset enumeration, use gb as option to also use gobuster"
	puts "	help\n\n"
	
	puts "Notes 
	set the GITHUB_TOKEN for github-subdomains
	tested on Windows, change 'type' with 'cat'"

end
