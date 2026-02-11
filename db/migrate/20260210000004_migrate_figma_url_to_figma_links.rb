# frozen_string_literal: true

class MigrateFigmaUrlToFigmaLinks < ActiveRecord::Migration[8.1]
  def up
    # Migrate existing figma_url data to figma_links table
    execute <<-SQL
      INSERT INTO figma_links (design_guidance_id, url, description, position, created_at, updated_at)
      SELECT id, figma_url, 'Migrated from legacy figma_url field', 0, NOW(), NOW()
      FROM design_guidances
      WHERE figma_url IS NOT NULL AND figma_url != ''
    SQL

    # Remove the old column
    remove_column :design_guidances, :figma_url
  end

  def down
    add_column :design_guidances, :figma_url, :string

    # Migrate back the first figma link for each design guidance
    execute <<-SQL
      UPDATE design_guidances
      SET figma_url = (
        SELECT url FROM figma_links 
        WHERE figma_links.design_guidance_id = design_guidances.id 
        ORDER BY position ASC 
        LIMIT 1
      )
    SQL
  end
end
