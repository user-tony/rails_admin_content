class RailsAdmin::Client < Mysql2::Client

	Syntax = /limit\s+\d+,\d+|limit\s+\d+/
	Syntax_table = /from\s+(\w+)/

	cattr_accessor :query_str, :total_nums, :table_name

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
		query_sql.downcase.match(Syntax).present? ? query_sql.downcase.gsub(Syntax, "limit #{page},#{stint}") : "#{query_sql} LIMIT #{page},#{stint}"
	end

	def self.get_tables
		@tables ? @tables : @tables = conn.origin_query('SHOW TABLES')
	end

	def self.compose(params)
		"SELECT * FROM #{params[:id]} #{compose_key(params)}"
	end

	def self.compose_key(params)
		case params[:calc]
		when '=', '>', '<'
			"WHERE #{params[:field]} #{params[:calc]} '#{params[:q]}' "
		when 'IN'
			"WHERE #{params[:field]} #{params[:calc]} (#{params[:q]}) "
		when '≠'
			"WHERE #{params[:field]} != '#{params[:q]}'"
		when 'LIKE'
			"WHERE #{params[:field]} LIKE '%#{params[:q]}%'"
		when 'IS NULL'
			"WHERE #{params[:field]} IS NULL"
		when '≥'
			"WHERE #{params[:field]} >= '#{params[:q]}'"
		when '≤'
			"WHERE #{params[:field]} <= '#{params[:q]}'"
		end
	end


	def self.delete(table_name, ids)
		conn.origin_query("DELETE FROM #{table_name} WHERE id IN (#{ids.join(',')})") if ids.is_a?(Array)
	end


end