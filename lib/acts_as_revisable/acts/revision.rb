require 'acts_as_revisable/clone_associations'

module FatJam
  module ActsAsRevisable
    module Revision
      def self.included(base)
        base.send(:extend, ClassMethods)
        
        class << base
          attr_accessor :revisable_revisable_class, :revisable_cloned_associations
        end
        
        base.instance_eval do
          set_table_name(revisable_class.table_name)
          acts_as_scoped_model :find => {:conditions => {:revisable_is_current => false}}
          
          CloneAssociations.clone_associations(revisable_class, self)
        
          define_callbacks :before_restore, :after_restore
        
          belongs_to :current_revision, :class_name => revisable_class_name, :foreign_key => :revisable_original_id
          belongs_to revisable_class_name.downcase.to_sym, :class_name  => revisable_class_name, :foreign_key => :revisable_original_id
          
          before_create :revision_setup
        end
      end
      
      def previous
        self.class.find(:first, :conditions => {:revisable_original_id => revisable_original_id, :revisable_number => revisable_number - 1})
      end
      
      def next
        self.class.find(:first, :conditions => {:revisable_original_id => revisable_original_id, :revisable_number => revisable_number + 1})
      end
      
      def revision_name=(val)
        self[:revisable_name] = val
      end
    
      def revision_name
        self[:revisable_name]
      end
    
      def revision_number
        self[:revisable_number]
      end
      
      def revision_setup
        now = Time.now
        prev = current_revision.revisions.first
        prev.update_attribute(:revisable_revised_at, now) if prev
        self[:revisable_current_at] = now + 1.second
        self[:revisable_is_current] = false
        self[:revisable_branched_from_id] = current_revision[:revisable_branched_from_id]
        self[:revisable_type] = current_revision[:type]
        self[:revisable_number] = (self.class.maximum(:revisable_number, :conditions => {:revisable_original_id => self[:revisable_original_id]}) || 0) + 1
      end
            
      module ClassMethods
        # Returns the +revisable_class_name+ as configured in
        # +acts_as_revisable+.
        def revisable_class_name
          self.revisable_options.revisable_class_name || self.class_name.gsub(/Revision/, '')
        end
      
        # Returns the actual +Revisable+ class based on the 
        # #revisable_class_name.
        def revisable_class
          self.revisable_revisable_class ||= revisable_class_name.constantize
        end
        
        # Returns the revision_class which in this case is simply +self+.
        def revision_class
          self
        end
        
        def revision_class_name
          self.name
        end
        
        def revision_cloned_associations
          clone_associations = self.revisable_options.clone_associations
        
          self.revisable_cloned_associations ||= if clone_associations.blank?
            []
          elsif clone_associations.eql? :all
            revisable_class.reflect_on_all_associations.map(&:name)
          elsif clone_associations.is_a? [].class
            clone_associations
          elsif clone_associations[:only]
            [clone_associations[:only]].flatten
          elsif clone_associations[:except]
            revisable_class.reflect_on_all_associations.map(&:name) - [clone_associations[:except]].flatten
          end        
        end
      end
    end
  end
end