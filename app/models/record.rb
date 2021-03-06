require 'rubygems'
require 'zip/zip'

class Record < ActiveRecord::Base    
  has_many :creators
  has_many :contributors
  has_many :descriptions
  has_many :subjects
  has_many :alternateIdentifiers
  has_many :datauploads
  has_many :relations
  has_many :submissionLogs
  has_many :uploads
  
  belongs_to :user
  attr_accessible :identifier, :identifierType, :publicationyear, :publisher, :resourcetype, :rights, :title, :local_id
  
  def set_local_id
    self.local_id = (0...10).map{ ('a'..'z').to_a[rand(26)] }.join
  end
  
  def create_record_directory
    FileUtils.mkdir("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}")
  end
  
  def review

    # can we define the character encoding at UTF without a byte recorder marker
    # ANSI encoding right now 
    
    # note - for now, removing the tags to contain multiple XML entries.  This produces invalid XML.
    # however, it appears to be necessary for the XTF index to work properly.  

     f = File.new("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/datacite.xml", "w:ASCII-8BIT")
    
     f.puts "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
     f.puts "<resource xmlns=\"http://datacite.org/schema/kernel-3\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://datacite.org/schema/kernel-3 http://schema.datacite.org/meta/kernel-3/metadata.xsd\">"
     
     # identifier - datacite: single, mandatory
     # left empty because it will be set by EZID on the merritt side
     f.puts "<identifier identifierType=\"DOI\"></identifier>"
     
     # creators - datacite: multiple, mandatory
     f.puts "<creators>"
     self.creators.each { |a| f.puts "<creator><creatorName>#{a.creatorName.gsub(/\r/,"")}</creatorName></creator>"}
     f.puts "</creators>"

     # should we allow multiple titles?  datacite does...
     # we're only allowing one title per record
     
     # titles - datacite: multiple, mandatory
     # datacite - title has an option type attribute that we are not using
     f.puts "<titles>"
     f.puts "<title>#{self.title}</title>"
     f.puts "</titles>"
     
     # publisher - datacite: single, mandatory
     f.puts "<publisher>#{self.publisher}</publisher>"
     
     # publication year - datacite: single, mandatory
     f.puts "<publicationYear>#{self.publicationyear}</publicationYear>"
     
     # subjects - datacite: multiple, optional
     f.puts "<subjects>"
     # subject scheme is optional and open
     #self.subjects.each { |a| f.puts "<subject subjectScheme=\"#{a.subjectScheme.gsub(/\r/,"")}\">#{a.subjectName.gsub(/\r/,"")}</subject>"}
     # for now, just use the subject without a scheme
     self.subjects.each { |a| f.puts "<subject>#{a.subjectName.gsub(/\r/,"")}</subject>"}
     f.puts "</subjects>"
         
     #contributors - datacite: multiple, optional, mandatory contributorType attribute
     # do we have a default value for contributorType?  
     # is this something we plan to use?
     f.puts "<contributors>"
     #self.contributors.each { |a| f.puts "<contributor contributorType=\"#{a.contributorType}\"><contributorName>#{a.contributorName.gsub(/\r/,"")}</contributorName></contributor>"}
     self.contributors.each { |a| f.puts "<contributor contributorType=\"ResearchGroup\"><contributorName>#{a.contributorName.gsub(/\r/,"")}</contributorName></contributor>"}
     f.puts "</contributors>"
     
     # resourceType - datacite: optional
     # should have a resourceTypeGeneral and a resourceType, may need to modify this
     #f.puts "<resourceType resourceTypeGeneral=\"#{self.resourcetype}\">#{self.resourcetype}</resourceType>"
     f.puts "<resourceType resourceTypeGeneral=\"Dataset\">Dataset</resourceType>"
     
     # alternate Identifiers - datacite: optional
     # this will be the localID
     #f.puts "<alternateIdentifiers>"
     #self.alternateIdentifiers.each { |a| f.puts "<alternateIdentifier alternateIdentifierType=\"#{a.alternateIdentifierType}\">#{a.alternateIdentifierName}</alternateIdentifier>"}
     #f.puts "</alternateIdentifiers>"
     
     # relatedIdentifiers - datacite: optional, multiple
     # going to use this for citations
     # and then relations doesn't exist in the datacite schema
     # is this valid without the relatedIdentifiersType?
     # should I be using a different description for this?  N
     # not sure if this is a valid mapping...
     #f.puts "<relatedIdentifiers>"
     #self.relations.each { |a| f.puts "<relatedIdentifier>#{a.relationText.gsub(/\r/,"")}</relatedIdentifier>"}
     #f.puts "</relatedIdentifiers>"
     
     #<sizes>... this will be exported from merritt, but do we need it in the metadata?
     
     # formats ?
     
     # version?
     
     #rights
     #not required
     #f.puts "<rights>#{self.rights}</rights>"
     
     #descriptions
     f.puts "<descriptions>" 
     
     # abstract
     if !self.abstract.nil?
       f.puts "<description descriptionType=\"Abstract\">#{CGI::escapeHTML(self.abstract.gsub(/\r/,""))}</description>"
     end
     
     #methods
     if !self.methods.nil?
       f.puts "<description descriptionType=\"Methods\">#{CGI::escapeHTML(self.methods.gsub(/\r/,""))}</description>"
     end
     
     # citation
       
     self.descriptions.each { |a| f.puts "<description descriptionType=\"SeriesInformation\">#{CGI::escapeHTML(a.descriptionText.gsub(/\r/,""))}</description>" }
       
     
     f.puts "</descriptions>"

     f.puts "</resource>"   
          
     f.close
     
     #return contents of file as string
     File.open("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/datacite.xml", "rb").read
   end
   
   def generate_merritt_zip
     file_path = "#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}"

    
     if File.exists?("#{file_path}/#{self.local_id}.zip")
       File.delete("#{file_path}/#{self.local_id}.zip")
     end
     
     zipfile_name = "#{file_path}/#{self.local_id}.zip"

     # target link and doi are generated by merritt
     # they are included here only for testing
     # uncomment if you need them in the archive (ie, if your repository does not supply these)
     f = File.new("#{file_path}/target_link", "w")  
     f.puts "http://localhost:3000/download_merritt_file/#{self.local_id}.zip"
     f.close

     f = File.new("#{file_path}/doi", "w")  
     f.puts "doi:10.7272/Q6057CV6"
     f.close

     f = File.new("#{file_path}/mrt-datacite.xml", "wb") 
     f.puts self.review
     f.close

     Zip::ZipFile.open(zipfile_name, Zip::ZipFile::CREATE) do |zipfile|       
       zipfile.add("mrt-datacite.xml", "#{file_path}/mrt-datacite.xml")
       
       self.purge_temp_files
       
       self.uploads.each do |d|  
          zipfile.add("#{d.upload_file_name}", "#{file_path}/#{d.upload_file_name}")
       end
     end

     # clean up all temp files (again, required because of the glitch in chunked file uploads)
     FileUtils.rm Dir[file_path + "/temp_*"]

   end

   # keep metadata records, but get rid of files that are no longer needed for local storate
   # (storage is intended only until records are uploaded to merritt)
   def purge_files(submission_log_id)
     
    uploads = Upload.find_all_by_record_id(self.id)
     
     # archive the file information for submission logs
    uploads.each do |u|
       upload_archive = UploadArchive.new
       upload_archive.submission_log_id = submission_log_id
       upload_archive.upload_file_name = u.upload_file_name
       upload_archive.upload_file_size = u.upload_file_size
       upload_archive.upload_content_type = u.upload_content_type
       upload_archive.save
     end
     
     Upload.delete_all(:record_id => self.id)

     file_path = "#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}"

     # delete the files from local storage now that they have been submitted to merritt
     if File.exists?("#{file_path}")
       FileUtils.rm_rf Dir.glob("#{file_path}/*")
     end
   end


   def send_archive_to_merritt

     # tics will execute, for now, just print to screen
      # note that the 2>&1 is to redirect sterr to stout
    
     sys_output = "curl --insecure --verbose -u #{MERRITT_CONFIG['merritt_username']}:#{MERRITT_CONFIG['merritt_password']} -F \"file=@./#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/#{self.local_id}.zip\" -F \"notification=#{self.user.email}\" -F \"type=container\" -F \"submitter=#{self.user.external_id}\" -F \"responseForm=xml\" -F \"profile=#{MERRITT_CONFIG['merritt_profile']}\" -F \"localIdentifier=#{self.local_id}\" #{MERRITT_CONFIG['merritt_endpoint']} 2>&1"
          
     return sys_output  
   end
   
   def required_fields
    
      required_fields = Array.new
    
      if self.creators.nil? || self.creators.empty?
        required_fields << "Record must specify at least one creator"
      end

      # should we allow multiple titles?  datacite does...
      # we're only allowing one title per record

      if self.title.nil? || self.title.blank?
        required_fields << "Record must have a title"
      end

      # publisher - datacite: single, mandatory
      if self.publisher.nil? || self.publisher.blank?
        required_fields << "Record must have a publisher"
      end

      # publication year - datacite: single, mandatory
      if self.publicationyear.nil?
        required_fields << "Record must have a publication year"
      end

      #contributors - datacite: multiple, optional, mandatory contributorType attribute
      # we will require contributors for datashare

      if self.contributors.nil? || self.contributors.empty?
        required_fields << "Record must specify at least one contributor"
      end
    
      return required_fields
   end
   
   def recommended_fields
   
      recommended_fields = Array.new
            
      # subjects - datacite: multiple, optional
      if self.subjects.nil? || self.subjects.empty?
        recommended_fields << "Subject data is strongly recommended.  Your record may be ommitted from search and browse results withough a subject"
      end
      
      #descriptions
 
      if self.abstract == "" || self.methods == ""
        recommended_fields << "While not required, an abstract and technical description are strongly recommended."
      end
 
      return recommended_fields
   
   end
  
  # temp files created for multipart uploads
  def purge_temp_files
    
    file_path = "#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}"
    
    self.uploads.each do |d| 
       
        # a temporary terrible hack to avoid the file corruption problem
        # on chunked uploads     
        
        if File.exist?(file_path + "/temp_" + d.upload_file_name)
          File.delete(file_path + "/" + d.upload_file_name)
          File.rename(file_path + "/temp_" + d.upload_file_name, file_path + "/" + d.upload_file_name)
        end
     end
  end
  
  
end