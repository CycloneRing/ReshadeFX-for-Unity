/*
 * Copyright (C) 2014 Patrick Mours. All rights reserved.
 * License: https://github.com/crosire/reshade#license
 */

#pragma once

namespace reshadefx_extra
{
	enum class special_uniform
	{
		none,
		frame_time,
		frame_count,
		random,
		ping_pong,
		date,
		timer,
		key,
		mouse_point,
		mouse_delta,
		mouse_button,
		mouse_wheel,
		freepie,
		overlay_open,
		overlay_active,
		overlay_hovered,
		bufready_depth,
	};
	struct uniform final : reshadefx::uniform_info
	{
		uniform(const reshadefx::uniform_info& init) : uniform_info(init) {}

		auto annotation_as_int(const char* ann_name, size_t i = 0, int default_value = 0) const
		{
			const auto it = std::find_if(annotations.begin(), annotations.end(),
				[ann_name](const auto& annotation) { return annotation.name == ann_name; });
			if (it == annotations.end()) return default_value;
			return it->type.is_integral() ? it->value.as_int[i] : static_cast<int>(it->value.as_float[i]);
		}
		auto annotation_as_float(const char* ann_name, size_t i = 0, float default_value = 0.0f) const
		{
			const auto it = std::find_if(annotations.begin(), annotations.end(),
				[ann_name](const auto& annotation) { return annotation.name == ann_name; });
			if (it == annotations.end()) return default_value;
			return it->type.is_floating_point() ? it->value.as_float[i] : static_cast<float>(it->value.as_int[i]);
		}
		auto annotation_as_string(const char* ann_name, const std::string_view& default_value = std::string_view()) const
		{
			const auto it = std::find_if(annotations.begin(), annotations.end(),
				[ann_name](const auto& annotation) { return annotation.name == ann_name; });
			if (it == annotations.end()) return default_value;
			return std::string_view(it->value.string_data);
		}

		bool supports_toggle_key() const
		{
			if (type.base == reshadefx::type::t_bool)
				return true;
			if (type.base != reshadefx::type::t_int && type.base != reshadefx::type::t_uint)
				return false;
			const std::string_view ui_type = annotation_as_string("ui_type");
			return ui_type == "list" || ui_type == "combo" || ui_type == "radio";
		}

		size_t effect_index = std::numeric_limits<size_t>::max();
		special_uniform special = special_uniform::none;
		uint32_t toggle_key_data[4] = {};
	};
}
