require 'box/item'
require 'box/file'

module Box
  # Represents a folder stored on Box. Any attributes or actions typical to
  # a Box folder can be accessed through this class.

  class Folder < Item
    def id
      super || @data[:folder_id]
    end

    # Create a new folder using this folder as the parent.
    #
    # @param [String] name The name of the new folder.
    # @return [Folder] The new folder.
    def create_folder(name)
      response = @api.create_folder(id, name)
      Box::Folder.new(@api, response.parsed_response)
    end

    # Upload a new file using this folder as the parent
    #
    # @param [String] path The path of the file on disk to upload.
    # @return [File] The new file.
    def upload_file(file)
      file = ::File.new(file) unless file.is_a?(::UploadIO) or file.is_a?(::File)

      response = @api.upload_file(id, file)
      Box::File.new(@api, response['file'])
    end

    def create_discussion(name)
      response = @api.create_discussion(id, name)
      Box::Discussion.new(@api, response.parsed_response)
    end

    def discussions
      response = @api.get_folder_discussions(id)
      response['discussions'].collect do |discussion|
        Box::Discussion.new(@api, discussion)
      end
    end

    # Delete this item and all sub-items.
    #
    # @return [Boolean] true
    def delete
      response = @api.delete_folder(id)
      Box::Folder.new(@api, response.parsed_response)
    end

    def update(params)
      response = @api.update_folder_info(id, @data)
      Box::Folder.new(@api, response.parsed_response)
    end

    # Search for sub-items using criteria.
    #
    # @param [Hash] criteria The hash of criteria to use. Each key of
    #        the criteria will be called on each sub-item and tested
    #        for equality. This lets you use any method of {Item}, {Folder},
    #        and {File} as the criteria.
    # @return [Array] An array of all sub-items that matched the criteria.
    #
    # @note The recursive option will call {#tree}, which can be slow for
    #       large folders.
    # @note Any item method (as a symbol) can be used as criteria, which
    #       could cause major problems if used improperly.
    #
    # @example Find all sub-items with the name 'README'
    #   folder.search(:name => 'README')
    #
    # @example Recusively find a sub-item with the given path.
    #   folder.search(:path => '/test/file.mp4', :recursive => true)
    #
    # @example Recursively find all files with a given sha1.
    #   folder.search(:type => 'file', :sha1 => 'abcdefg', :recursive => true)
    #
    # TODO: Lookup YARD syntax for options hash.
    def find(criteria)
      recursive = criteria.delete(:recursive)
      find!(criteria, !!recursive)
    end

    # Get the item at the given path.
    #
    # @param [String] The path to search for. This follows the typical unix
    #                 path syntax, in that the root folder is '/'. Supports
    #                 the dot sytax, where '.' is the current folder and
    #                 '..' is the parent folder.
    #
    # @return [Item]  The item that exists at this path, or nil.
    #
    # @example Find a folder based on its absolute path.
    #   folder.at('/box/is/awesome')
    #
    # @example Find a file based on a relative path.
    #   folder.at('awesome/file.pdf')
    #
    # @example Find a folder using the parent.
    #   folder.at('../other/folder')
    def at(target_path)
      # start with this folder
      current = self

      if target_path.start_with?('/')
        # absolute path, find the root folder
        current = current.parent while current.parent != nil
      end

      # split each part of the target path
      target_path.split('/').each do |target_name|
        # update current based on the target name
        current = case target_name
        when "", "."
          # no-op
          current
        when ".."
          # use the parent folder
          parent
        else
          # must be a file/folder name, so make sure this is a folder
          return nil unless current and current.type == 'folder'

          # search for an item with that name
          current.find(:name => target_name, :recursive => false).first
        end
      end

      if current
        # ends with a slash, so it has to be a folder
        if target_path.end_with?('/') and current.type != 'folder'
          # get the folder with the same name (if it exists)
          current = parent.find(:type => 'folder', :name => name, :recursive => false).first
        end
      end

      current
    end

    def files
      #items.select { |item| item and item.class == Box::File }
      response = @api.get_folder_info(id)
      response
    end

    def folders
      items.select { |item| item and item.class == Box::Folder }
    end

    protected

    # (see Item#get_info)
    def get_info
      response = @api.get_folder_info(id)
      response.parsed_response
    end

    # (see #find)
    def find!(criteria, recursive)
      matches = items.collect do |item| # search over our files and folders
        match = criteria.all? do |key, value| # make sure all criteria pass
          value === item.send(key) rescue false
        end

        item if match # use the item if it is a match
      end

      if recursive
        folders.each do |folder| # recursive step
          matches += folder.find!(criteria, recursive) # search each folder
        end
      end

      matches.compact # return the results without nils
    end
  end
end
