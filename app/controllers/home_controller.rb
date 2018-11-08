require 'google/apis/drive_v2'
require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'openssl'
require 'fileutils'
require 'net/http'
require 'open-uri'
require 'signet/oauth_2/client'
require 'aws-sdk'

class HomeController < ApplicationController

  skip_before_action :verify_authenticity_token

  
  def index
    @credentials = get_credentials

    return redirect_to authenticate if @credentials.blank?
    result = ''
    # create_folder
    @drive = Google::Apis::DriveV2::DriveService.new
    @drive.authorization = @credentials
    # create_file
    @files = @drive.list_files(q: "'root' in parents and explicitly_trashed=false", order_by: 'folder')
  end

  def create_folder(folder_name)
    drivev3 = Google::Apis::DriveV3::DriveService.new
    drivev3.authorization = get_credentials
    file_metadata = {
        name: folder_name,
        mime_type: 'application/vnd.google-apps.folder'
    }
    file = drivev3.create_file(file_metadata, fields: 'id')
    puts "Folder Id: #{file.id}"
  end

  def upload_new_file
    file = params[:new_file]
    if file.present?
      create_file(file)
    end
    redirect_to root_path
  end

  def create_file(file)
    @drive = Google::Apis::DriveV2::DriveService.new
    @drive.authorization = get_credentials
    metadata =  Google::Apis::DriveV2::File.new(title: file.original_filename)
    metadata = @drive.insert_file(metadata, upload_source: file.tempfile, content_type: file.content_type)
    puts metadata
  end

  def create_new_folder
    @folder_name = params[:folder_name]
    return if @folder_name.blank?
    create_folder(@folder_name)
  end

  def delete_existing_folder
    file_id = params[:file_id]
    return if file_id.blank?
    delete_folder(file_id)
    redirect_to root_path
  end

  def delete_folder(file_id)
    drivev3 = Google::Apis::DriveV3::DriveService.new
    drivev3.authorization = get_credentials
    drivev3.delete_file(file_id)
  end

  def authenticate
    @user_id = '2005'
    @client_id = Google::Auth::ClientId.from_file('public/google/client_secret.json')
    @token_store = Google::Auth::Stores::FileTokenStore.new(file: 'public/google/client_secret.yaml')
    @authorizer = Google::Auth::UserAuthorizer.new(@client_id, ['https://www.googleapis.com/auth/drive'], @token_store, 'http://localhost:3000/home/callback')
    @credentials = @authorizer.get_credentials(@user_id)
    @url = @authorizer.get_authorization_url(base_url: 'http://localhost:3000/home/callback')
    @url
  end

  def download_file
    file_id = params[:file_id]
    mime_type = params[:mime_type]
    title = params[:title]
    drivev3 = Google::Apis::DriveV3::DriveService.new
    drivev3.authorization = get_credentials
    file_path = "public/temp/"+title
    drivev3.get_file(file_id, download_dest: file_path)
    send_file file_path, :filename => title, :type => mime_type, :disposition => "attachment"
  end

  def callback
    puts params
    code = params[:code]
    if code.present?
      @user_id = '2005'
      @client_id = Google::Auth::ClientId.from_file('public/google/client_secret.json')
      @token_store = Google::Auth::Stores::FileTokenStore.new(file: 'public/google/client_secret.yaml')
      @authorizer = Google::Auth::UserAuthorizer.new(@client_id,
                                                     ['https://www.googleapis.com/auth/drive'],
                                                     @token_store,
                                                     'http://localhost:3000/home/callback')
      @credentials = @authorizer.get_and_store_credentials_from_code(user_id: @user_id,
                                                                     code: params[:code],
                                                                     base_url: @call_back_url)

      redirect_to root_path
    else
      render plain: params
    end
  end

  def folder_view
    @credentials = get_credentials
    return redirect_to authenticate if @credentials.blank?
    result = ''
    # create_folder
    @drive = Google::Apis::DriveV2::DriveService.new
    @drive.authorization = @credentials
    if params[:folder_id].blank?
      # create_file
      @files = @drive.list_files(q: "'root' in parents", order_by: 'folder')
    else
      folder_id = params[:folder_id]
      @files = @drive.list_files(q: "'"+ folder_id + "' in parents", order_by: 'folder')
    end
  end

  private

  def get_credentials
    client_id = Google::Auth::ClientId.from_file('public/google/client_secret.json')
    token_store = Google::Auth::Stores::FileTokenStore.new(file: 'public/google/client_secret.yaml')
    authorizer = Google::Auth::UserAuthorizer.new(client_id,
                                                  ['https://www.googleapis.com/auth/drive'],
                                                  token_store,
                                                  'http://localhost:3000/home/callback')
    authorizer.get_credentials('2005')
  end
end