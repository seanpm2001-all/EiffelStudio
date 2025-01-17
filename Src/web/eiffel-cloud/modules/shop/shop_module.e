note
	description: "Summary description for {SHOP_MODULE}."
	date: "$Date$"
	revision: "$Revision$"

class
	SHOP_MODULE

inherit
	CMS_MODULE
		rename
			module_api as shop_api
		redefine
			initialize,
			install,
			setup_hooks,
			shop_api,
			permissions
		end

--	CMS_WITH_MODULE_ADMINISTRATION

	CMS_WITH_WEBAPI

	CMS_HOOK_MENU_SYSTEM_ALTER

	STRIPE_HOOK

	CMS_HOOK_AUTO_REGISTER

create
	make

feature {NONE} -- Initialization

	make
		do
			version := "1.1"
			description := "Shopping system"
			package := "shop"
			add_dependency ({CMS_AUTHENTICATION_MODULE})
		end

feature -- Access

	name: STRING = "shop"

feature {CMS_MODULE} -- Access control

	permissions: LIST [READABLE_STRING_8]
			-- <Precursor>
		do
			Result := Precursor
			Result.force ("manage shop")
		end

feature {CMS_API} -- Module Initialization

	initialize (api: CMS_API)
			-- <Precursor>
		local
			cfg: SHOP_CONFIG
			l_shop_name: detachable READABLE_STRING_32
		do
			Precursor (api)
			if shop_api = Void then
				if
					attached api.module_configuration_by_name ({SHOP_MODULE}.name, "config") as l_cfg
				then
					l_shop_name := l_cfg.resolved_text_item ("shop.name")
					if l_shop_name = Void then
						l_shop_name := api.setup.site_name
					end
					create cfg.make (l_shop_name)
					if attached l_cfg.resolved_text_item ("shop.id") as s then
						cfg.set_shop_id (s.to_string_8)
					end
					if attached l_cfg.resolved_text_item ("shop.cookie_name") as s then
						cfg.set_cookie_name (s.to_string_8)
					end
					if attached l_cfg.resolved_text_item ("shop.currency") as s then
						cfg.set_default_currency (s.to_string_8)
					end
					if attached l_cfg.utf_8_text_item ("shop.base_path") as l_base_path then
						if l_base_path.starts_with_general ("/") then
							cfg.set_base_path (l_base_path)
						else
							cfg.set_base_location (l_base_path)
						end
					end
					create shop_api.make (Current, api, cfg)
				end
			end
		end

feature {CMS_API} -- Module management

	install (api: CMS_API)
		do
			Precursor (api)
			if attached api.storage.as_sql_storage as l_sql_storage then
				l_sql_storage.sql_execute_file_script (api.module_resource_location (Current, (create {PATH}.make_from_string ("scripts")).extended ("install.sql")), Void)

				if l_sql_storage.has_error then
					api.logger.put_error ("Could not initialize database for module [" + name + "]", generating_type)
				else
					Precursor {CMS_MODULE} (api)
				end
			end
			if is_installed (api) then
			end
		end

feature {NONE} -- Administration

--	administration: SHOP_MODULE_ADMINISTRATION
--		do
--			create Result.make (Current)
--		end

feature {NONE} -- Webapi

	webapi: SHOP_MODULE_WEBAPI
		do
			create Result.make (Current)
		end

feature {CMS_API, CMS_MODULE_API, CMS_MODULE} -- Access: API

	shop_api: detachable SHOP_API
			-- <Precursor>

feature -- Access: router

	setup_router (a_router: WSF_ROUTER; a_api: CMS_API)
			-- <Precursor>
		do
			if attached shop_api as l_mod_api then
				a_router.handle (l_mod_api.config.base_path + "/not_available", create {WSF_URI_AGENT_HANDLER}.make (agent handle_not_available (?,?, a_api)), a_router.methods_get)
				a_router.handle (l_mod_api.config.base_path + "/", create {SHOP_HANDLER}.make (Current, l_mod_api, l_mod_api.config.base_path), a_router.methods_get)

				a_router.handle (l_mod_api.config.base_path + "/" + cart_sub_location, create {SHOP_CART_HANDLER}.make (Current, l_mod_api, l_mod_api.config.base_path), a_router.methods_get_post)
			end
		end

	cart_sub_location: STRING = "cart/"

feature -- Helper

--	checkout_link (a_category: READABLE_STRING_GENERAL; a_product: READABLE_STRING_GENERAL): READABLE_STRING_8
--			-- Payment url for category `a_category` and product `a_product`.
--		do
--			if attached shop_api as l_shop_api and then l_shop_api.config.is_valid then
--				Result := l_shop_api.config.base_path + "/pay/" + html_encoded (a_category) + "/" + html_encoded (a_product)
--			else
--				Result := {SHOP_CONFIG}.default_base_path + "/not_available"
--			end
--		end

	wipe_out_cart_link (a_cart: SHOPPING_CART): READABLE_STRING_8
		do
			if attached shop_api as l_shop_api and then l_shop_api.config.is_valid then
				Result := l_shop_api.config.base_path + "/" + cart_sub_location + "?remove=all"
				if attached a_cart.security as l_sec then
					Result := Result + "&security=" + url_encoded (l_sec)
				end
			else
				Result := {SHOP_CONFIG}.default_base_path + "/not_available"
			end
		end

	submit_single_item_link (a_provider: READABLE_STRING_GENERAL; a_item_code: READABLE_STRING_GENERAL): READABLE_STRING_8
		do
			if attached shop_api as l_shop_api and then l_shop_api.config.is_valid then
				Result := l_shop_api.config.base_path + "/" + cart_sub_location + "?itemProvider=" + url_encoded (a_provider) + "&itemCode=" + url_encoded (a_item_code)
			else
				Result := {SHOP_CONFIG}.default_base_path + "/not_available"
			end
		end

feature -- Routes

	handle_not_available (req: WSF_REQUEST; res: WSF_RESPONSE; api: CMS_API)
			-- If shop configuration is not valid, return not available response.
		local
			r: GENERIC_VIEW_CMS_RESPONSE
		do
			create r.make (req, res, api)
			r.set_main_content ("<h2>Not available</h2>")
			r.execute
		end

feature -- Hooks configuration

	setup_hooks (a_hooks: CMS_HOOK_CORE_MANAGER)
			-- Module hooks configuration.
		do
			a_hooks.subscribe_to_menu_system_alter_hook (Current)
			a_hooks.subscribe_to_hook (Current, {STRIPE_HOOK})
		end

feature -- Hook		

	menu_system_alter (a_menu_system: CMS_MENU_SYSTEM; a_response: CMS_RESPONSE)
			-- Hook execution on collection of menu contained by `a_menu_system'
			-- for related response `a_response'.
		local
			lnk: CMS_LOCAL_LINK
		do
			if attached shop_api as l_shop_api then
				if attached l_shop_api.active_shopping_cart (a_response.request) as l_cart and then l_cart.count > 0 then
					create lnk.make ({STRING_32} "%/128722/" + {STRING_32} "(" + l_cart.count.out + ")", a_response.location_url ("shop/cart/", Void))
					lnk.set_weight (100)
					lnk.add_css_class ("shopping-cart-live")
					a_menu_system.primary_menu.extend (lnk)
				end
			end
		end

feature -- Hook

	prepare_payment (pay: STRIPE_PAYMENT)
		local
			l_cart: SHOPPING_CART
			cname: READABLE_STRING_GENERAL
			l_sub_item: STRIPE_PAYMENT_SUBSCRIPTION_ITEM
			l_onetime_item: STRIPE_PAYMENT_ONETIME_ITEM
			l_plan: STRIPE_PLAN
			l_product_id: READABLE_STRING_GENERAL
			l_price_in_cents: NATURAL_32
		do
			if
				attached shop_api as l_shop_api and then
				pay.category.is_case_insensitive_equal_general (l_shop_api.config.shop_id)
			then
				if attached pay.checkout_id as pn then
					cname := pn

					if attached l_shop_api.cms_api.user as u then
						pay.set_customer_name (l_shop_api.cms_api.user_display_name (u))
						pay.set_customer_email (u.email)

						l_cart := l_shop_api.user_shopping_cart (u)
						if l_cart /= Void then
							if not l_cart.is_identified_by (cname) then
								l_cart := Void
							end
						end
					else
						l_cart := l_shop_api.guest_shopping_cart (cname)
					end
					if l_cart /= Void then
						l_cart.set_currency (pay.currency)
						l_shop_api.invoke_shop_fill_cart (l_cart)
						if l_cart.has_incomplete_item then
								-- Should not happen!!!
						else
							pay.set_title (l_cart.cart_title (Void))
							pay.set_code (l_cart.cart_name (Void))
							pay.set_business_name (l_cart.provider_name (l_shop_api.config.shop_name))
							pay.set_price (l_cart.price_in_cents, l_cart.currency)
							pay.set_order_id (l_cart.identifier)
							across
								l_cart.items as ic
							loop
								if
									attached {SHOPPING_ITEM} ic.item as l_shop_item and then
									attached {SHOPPING_ITEM_DETAILS} l_shop_item.details as l_details then
									if l_details.is_onetime then
										create l_onetime_item.make (l_shop_item.provider, l_details.price_in_cents, l_details.currency)
										pay.add_item (l_onetime_item)
									else
										l_product_id := l_shop_item.provider + "." + l_shop_item.code
											-- yearly, monthly, ...
										l_price_in_cents := l_details.price_in_cents * l_shop_item.quantity
										if l_details.is_yearly then
											create l_plan.make_yearly (l_price_in_cents, l_details.currency, l_details.interval_count, l_product_id)
										elseif l_details.is_monthly then
											create l_plan.make_monthly (l_price_in_cents, l_details.currency, l_details.interval_count, l_product_id)
										elseif l_details.is_weekly then
											create l_plan.make_weekly (l_price_in_cents, l_details.currency, l_details.interval_count, l_product_id)
										elseif l_details.is_daily then
											create l_plan.make_daily (l_price_in_cents, l_details.currency, l_details.interval_count, l_product_id)
										else
											create l_plan.make_yearly (l_price_in_cents, l_details.currency, l_details.interval_count, l_product_id)
										end
										create l_sub_item.make (if attached l_plan.identifier as l_id then l_id else l_product_id end, l_plan, l_shop_item.quantity)
										pay.add_item (l_sub_item)
									end
								end
							end
							pay.mark_prepared
						end
					end
				end
			end
		end

	validate_payment (a_validation: STRIPE_PAYMENT_VALIDATION)
		local
			l_invoice: STRIPE_INVOICE
			l_email_addr: READABLE_STRING_8
			l_customer_name: READABLE_STRING_32
			l_order_id: detachable IMMUTABLE_STRING_32
			vars: STRING_TABLE [detachable ANY]
			l_shop_cart: SHOPPING_CART
			l_order: SHOPPING_ORDER
			i: INTEGER
			l_provider, l_code: READABLE_STRING_GENERAL
			l_quantity: NATURAL_32
			l_shop_item: SHOPPING_ITEM
			l_units,l_cents: STRING
			s: STRING
		do
			if attached shop_api as l_shop_api then
				l_order_id := a_validation.order_id
				l_invoice := a_validation.invoice
				l_email_addr := a_validation.customer.email
				l_customer_name := a_validation.customer.name
				if l_email_addr = Void then
					if l_invoice /= Void then
						l_email_addr := l_invoice.customer_email
					elseif attached l_shop_api.cms_api.user as u then
						l_email_addr := u.email
					end
				end
				if l_customer_name = Void then
					if l_invoice /= Void then
						l_customer_name := l_invoice.customer_name
					elseif attached l_shop_api.cms_api.user as u then
						l_customer_name := u.profile_name
						if l_customer_name = Void then
							l_customer_name := u.name
						end
					end
				end

				l_order := l_shop_api.order (l_order_id)
				if l_order /= Void and a_validation.is_subscription_cycle then
					if l_order.reference_id = Void and then attached a_validation.reference_id as ref then
						l_order.set_reference_id (ref)
					end
					l_shop_cart := l_order.associated_cart
					if l_email_addr = Void then
						l_email_addr := l_order.email
					end
				else
					if l_order_id /= Void then
						l_shop_cart := l_shop_api.shopping_cart (l_order_id)
					end
					if l_shop_cart = Void then
						if attached l_shop_api.cms_api.user as u then
							l_shop_cart := l_shop_api.user_shopping_cart (u)
						elseif l_email_addr /= Void then
							l_shop_cart := l_shop_api.shopping_cart_by_email (l_email_addr)
						else
							check has_cart: False end
						end
					end
					if
						l_shop_cart = Void and then
						l_invoice /= Void
					then
							-- Try to compute the cart from the invoice, if any.
						l_shop_cart := l_shop_api.new_guest_cart
						l_shop_cart.set_currency (l_invoice.currency)
						if attached l_invoice.lines as l_lines then
							across
								l_lines as ic
							loop
								if
									attached ic.item as l_invoice_line and then
									l_invoice_line.is_subscription_type and then
									attached l_invoice_line.plan as l_plan and then
									attached l_plan.nickname as l_plan_nickname
								then
									i := l_plan_nickname.index_of ('.', 1)
									if i > 0 then
										l_provider := l_plan_nickname.head (i - 1)
										l_code := l_plan_nickname.substring (i + 1, l_plan_nickname.count)
										l_quantity := l_invoice_line.quantity
										create l_shop_item.make (l_code, l_provider)
										l_shop_item.set_quantity (l_quantity)
										l_shop_cart.add_item (l_shop_item)
									end
								end
							end
						end
					end
				end
				if l_email_addr = Void and l_shop_cart /= Void then
					l_email_addr := l_shop_cart.email
				end
				if l_email_addr /= Void then
					create vars.make_caseless (3)
					vars ["payment_validation"] := a_validation
					vars ["receipt_or_invoice_urls"] := a_validation.receipt_or_invoice_urls
					vars ["products"] := a_validation.products
					if a_validation.amount_paid > 0 then
						s := a_validation.amount_paid.out
						s.adjust
						if s.count > 2 then
							l_units := s.substring (1, s.count - 2)
						else
							l_units := "0"
						end
						l_cents := s.substring (s.count - 1, s.count)
						if l_cents.is_case_insensitive_equal_general ("00") then
							vars ["amount_paid"] := l_units
						else
							vars ["amount_paid"] := l_units + "." + l_cents
						end
						vars ["currency"] := a_validation.currency
					end
					vars ["customer_name"] := l_customer_name

					if
						l_shop_cart /= Void and then
						attached l_shop_cart.provider_name (l_shop_api.config.shop_name) as l_prov_name
					then
						vars ["business_name"] := l_prov_name
					else
						vars ["business_name"] := l_shop_api.config.shop_name
					end
					if l_invoice /= Void then
						vars ["invoice"] := l_invoice
						vars ["invoice_url"] := l_invoice.hosted_invoice_url
						vars ["invoice_pdf"] := l_invoice.invoice_pdf
					end
					if a_validation.is_subscription_cycle then
						if attached l_shop_api.subscription_cycle_confirmation_email (l_email_addr, vars) as e then
							l_shop_api.cms_api.process_email (e)
						end
					else
						if attached l_shop_api.order_confirmation_email (l_email_addr, vars) as e then
							l_shop_api.cms_api.process_email (e)
						end
					end
				end
				if l_shop_cart /= Void then
					check l_order_id /= Void implies l_shop_cart.is_identified_by (l_order_id) end
					if l_email_addr /= Void and l_shop_cart.email = Void then
						l_shop_cart.set_email (l_email_addr)
					end
					if l_order = Void then
						l_order := l_shop_api.cart_to_order (l_shop_cart, a_validation.reference_id)
					end
					l_shop_api.invoke_commit_cart (l_shop_cart, l_order)
				else
					l_shop_api.cms_api.log_debug (name, "Missing shopping cart information during payment validation.", Void)
				end
			end
		end

end
