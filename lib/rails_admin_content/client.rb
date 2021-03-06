class RailsAdminContent::Client < Mysql2::Client

  Syntax = /limit\s+\d+,\d+|limit\s+\d+/
  Syntax_table = /from\s+(\w+)/

  cattr_accessor :query_str, :total_nums, :table_name

  def self.select_field(type)
    case type.gsub(/\(.*?\)/,'')
    when "tinyint" then [['等于', '='], ['不等于', '≠']]
    when "datetime" then [['等于', '='], ['不等于', '≠'], ['大于', '>'], ['小于','<']]
    when "int" then [['等于', '='], ['不等于', '≠'], ['大于', '>'], ['小于','<'], ['含有', 'IN']]
    else
      [['等于', '='], ['不等于', '≠'], ['包含', 'LIKE']]
    end
  end

  def self.conn
    @client ||= new ActiveRecord::Base.connection_config
  end

  alias :origin_query :query

  def self.query(query_sql, page=nil, stint=nil)
    self.table_name = query_sql.downcase.match(Syntax_table)[1] if query_sql.downcase.match(Syntax_table)
    self.total_nums = conn.origin_query(query_sql).size
    query_sql = limit(query_sql, page, stint) if stint && page
    query_sql = query_sql.gsub(/;/, '')
    conn.origin_query(query_sql)
  end

  def self.limit(query_sql, page=1, stint)
    page = page == 1 ? page = 0 : page.to_i*stint.to_i-stint.to_i
    query_sql.downcase.match(Syntax).present? ? query_sql.downcase.gsub(Syntax, "LIMIT #{page},#{stint}") : "#{query_sql} LIMIT #{page},#{stint}"
  end

  def self.get_tables
    @tables ? @tables : @tables = conn.origin_query('SHOW TABLES')
  end

  def self.compose(params)
    "SELECT * FROM #{params[:id]} WHERE #{params["field"].inject([]){|a, (key,value)| a << compose_key(params["calc"][key],key, value); a }.join('and')}"
  end

  def self.compose_key(calc,key,value)
    case calc
    when '=', '>', '<'
      " `#{key}` #{calc} '#{value}' "
    when 'IN'
      " `#{key}` IN (#{value}) "
    when '≠'
      " `#{key}`  != '#{value}' "
    when 'LIKE'
      " `#{key}` LIKE '%#{value}%' "
    when '≥'
      " `#{key}`  >= '#{value}' "
    when '≤'
      " `#{key}`  <= '#{value}' "
    end
  end


  def self.delete(table_name, ids)
    conn.origin_query("DELETE FROM #{table_name} WHERE id IN (#{ids.join(',')})") if ids.is_a?(Array)
  end

  def self.insert(table_name, field)
    conn.origin_query("INSERT INTO #{table_name} (#{field.keys.join(',')}) VALUES ('#{field.values.join("','")}')")
  end

  def self.update(table_name, id, fields)
    conn.origin_query "UPDATE #{table_name} SET #{compose_update_sql(table_name, fields.to_a)}  WHERE id = #{id}"
  end

  def self.compose_update_sql(table_name,fields)
    columns = desc_table(table_name)
    fields.inject([]) do |array, field|
      columns.each do |column|
        if field[1].present? && field[0] == column["Field"]
          value = case column["Type"].gsub(/\(.*?\)/,'')
          when 'int', 'decimal', 'tinyint' then field[1]
          when 'datetime' then "'#{field[1]}'"
          else
            "REPLACE(REPLACE(REPLACE('#{field[1]}', '&','&amp;'), '>', '&gt;'), '<', '&lt;')"
          end
          array << "#{table_name}.`#{field[0]}` = #{value}"
        end
      end
      array
    end.join(' , ')
  end

  def self.desc_table(table_name)
    conn.origin_query("DESC #{table_name}").each
  end

  def self.show_create_sql(table_name)
    conn.origin_query("SHOW CREATE TABLE #{table_name}").each
  end

  def self.modify_table_column_default_value(table_name, column, value, field_type)
    default_value = case field_type.gsub(/\(.*?\)/,'')
    when "tinyint" then value.present?
    when "datetime" then value.to_time.to_s(:db)
    when "int" then value.to_i
    else
      value.to_s
    end
    conn.origin_query("ALTER TABLE #{table_name} ALTER COLUMN #{column} SET DEFAULT '#{default_value}'")
  end

end
