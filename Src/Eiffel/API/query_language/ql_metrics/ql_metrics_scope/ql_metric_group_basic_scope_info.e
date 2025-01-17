note
	description: "Representation of group basic scope of a metric"
	legal: "See notice at end of class."
	status: "See notice at end of class."
	date: "$Date$"
	revision: "$Revision$"

class
	QL_METRIC_GROUP_BASIC_SCOPE_INFO

inherit
	QL_METRIC_BASIC_SCOPE_INFO
		redefine
			calculate_function,
			domain_generator
		end

create
	make

feature{NONE} -- Initialization

	make (a_calculate_func: like calculate_function)
			-- Initialize `calculate_function' with `a_calculate_func'.
		do
			create domain_generator
			domain_generator.item_satisfied_actions.extend (agent evaluate_item)
			calculate_function := a_calculate_func
		ensure
			domain_generator_created: domain_generator /= Void
			calculate_function_set: calculate_function = a_calculate_func
		end

feature -- Access

	scope: QL_SCOPE
			-- Scope
		do
			Result := group_scope
		ensure then
			good_result: Result = group_scope
		end

	calculate_function: FUNCTION [QL_GROUP, DOUBLE]
			-- Function to calculate metric

	domain_generator: QL_GROUP_DOMAIN_GENERATOR
			-- Domain generator used to calculate metric

feature{NONE} -- Implementation

	evaluate_item (a_item: QL_GROUP)
			-- Call `calculate_function' to evaluate `a_item'.
		do
			if calculate_function /= Void then
				metric.increase_value_by (calculate_function.item ([a_item]))
			else
					-- If no calculation algorithm is provided for `a_item', we just do simple counting.
				metric.increase_value_by (1.0)
			end
		end

invariant
	scope_valid: scope.is_equal (group_scope)

note
	copyright: "Copyright (c) 1984-2013, Eiffel Software"
	license: "GPL version 2 (see http://www.eiffel.com/licensing/gpl.txt)"
	licensing_options: "http://www.eiffel.com/licensing"
	copying: "[
			This file is part of Eiffel Software's Eiffel Development Environment.
			
			Eiffel Software's Eiffel Development Environment is free
			software; you can redistribute it and/or modify it under
			the terms of the GNU General Public License as published
			by the Free Software Foundation, version 2 of the License
			(available at the URL listed under "license" above).
			
			Eiffel Software's Eiffel Development Environment is
			distributed in the hope that it will be useful, but
			WITHOUT ANY WARRANTY; without even the implied warranty
			of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
			See the GNU General Public License for more details.
			
			You should have received a copy of the GNU General Public
			License along with Eiffel Software's Eiffel Development
			Environment; if not, write to the Free Software Foundation,
			Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
		]"
	source: "[
			Eiffel Software
			5949 Hollister Ave., Goleta, CA 93117 USA
			Telephone 805-685-1006, Fax 805-685-6869
			Website http://www.eiffel.com
			Customer support http://support.eiffel.com
		]"

end
