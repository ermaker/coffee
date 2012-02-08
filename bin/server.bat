@ECHO OFF
cd "%~dp0.."
bundle exec guard -G "%~dp0..\config\server_guardfile.rb" -w "C:\Program Files\hMailServer\Data\hcid.kaist.ac.kr\analyzer"
