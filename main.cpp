#include <fstream>
#include <map>
#include <sstream>
#include <vector>

#define _REALLY_INCLUDE_SYS__SYSTEM_PROPERTIES_H_
#include <sys/_system_properties.h>

// Override the value of a system property with a new value
// Params:
// - prop: The name of the system property to override
// - value: The new value for the system property
// - add: Flag to indicate whether to add the property if it doesn't exist
// (default: false)
void property_override(char const prop[], char const value[],
                       bool add = false) {
  // Find the system property by name
  auto pi = (prop_info *)__system_property_find(prop);

  if (pi != nullptr) {
    // If the property already exists, update its value with the new value
    __system_property_update(pi, value, strlen(value));
  } else if (add) {
    // If the property doesn't exist and add flag is true, add the property with
    // the new value
    __system_property_add(prop, strlen(prop), value, strlen(value));
  }
}

// Override the value of multiple system properties with the same new value
// Params:
// - props: A vector of system property names to override
// - value: The new value for the system properties
// - add: Flag to indicate whether to add the properties if they don't exist
// (default: false)
void property_override(const std::vector<std::string> &props,
                       char const value[], bool add = false) {
  for (const auto &prop : props) {
    // Call the single-property override function for each property in the
    // vector
    property_override(prop.c_str(), value, add);
  }
}

// Get the configuration file name based on system properties
// Returns: A std::string containing the configuration file name
std::string get_config_filename() {
  // Default configuration file name
  std::string filename = "/system/etc/ih8sn.conf";
  // Array of system property names to check
  const char *prop_names[] = {"ro.build.product", "ro.build.model",
                              "ro.boot.serialno"};

  // Iterate through each system property name in the array
  for (auto &prop_name : prop_names) {
    // Find the system property by name
    auto prop = (prop_info *)__system_property_find(prop_name);
    if (prop != nullptr) {
      // Buffer to store the system property value
      char prop_value[PROP_VALUE_MAX];
      // Read the system property value
      __system_property_read(prop, nullptr, prop_value);

      // Replace spaces with underscores in prop_value, except at the end
      for (size_t i = 0; i < strlen(prop_value) - 1; ++i) {
        if (prop_value[i] == ' ' && prop_value[i + 1] != ' ') {
          prop_value[i] = '_';
        }
      }

      // Check for file with underscores in prop_value
      // Append prop_value to filename with underscores
      std::string prop_filename = filename + "." + prop_value;
      // Check if the file with prop_filename exists
      if (std::ifstream(prop_filename)) {
        // If found, return the file name with underscores
        return prop_filename;
      }

      // Check for file with spaces in prop_value
      // Reset prop_filename
      prop_filename = filename + "." + prop_value;
      // Replace underscores with spaces
      std::replace(prop_filename.begin(), prop_filename.end(), '_', ' ');
      // Check if the file with prop_filename exists
      if (std::ifstream(prop_filename)) {
        // If found, return the file name with spaces
        return prop_filename;
      }
    }
  }

  // If no file with spaces or underscores was found, return the original
  // filename
  return filename;
}

// Load configuration data from a file into a std::map
// Returns: A std::map containing the configuration data as key-value pairs
std::map<std::string, std::string> load_config() {
  // Create a std::map to store the configuration data
  std::map<std::string, std::string> config;

  // Open the configuration file using std::ifstream, and check if it is in good
  // state
  if (std::ifstream file(get_config_filename()); file.good()) {
    // Variable to store each line read from the file
    std::string line;

    // Read each line from the file using std::getline()
    while (std::getline(file, line)) {
      // Skip lines that start with '#' as they are considered comments
      if (line[0] == '#') {
        continue;
      }

      // If a line contains a '=' character, parse it as a key-value pair
      if (const auto separator = line.find('=');
          separator != std::string::npos) {
        // Extract the key and value substrings and store them in the std::map
        config[line.substr(0, separator)] = line.substr(separator + 1);
      }
    }
  }

  // Return the std::map containing the configuration data
  return config;
}

// Generate a list of property names based on prefix and suffix
// Params:
// - prefix: A const reference to a std::string representing the prefix to be
// added to property names
// - suffix: A const reference to a std::string representing the suffix to be
// added to property names Returns: A std::vector<std::string> containing the
// generated property names
std::vector<std::string> property_list(const std::string &prefix,
                                       const std::string &suffix) {
  // Vector to store the generated property names
  std::vector<std::string> props;

  // Iterate through a list of parts to be appended to the prefix
  for (const std::string &part : {
           "",
           "board.",
           "boot.",
           "bootimage.",
           "odm_dlkm.",
           "odm.",
           "oem.",
           "product.",
           "system_dlkm.",
           "system_ext.",
           "system.",
           "vendor_dlkm.",
           "vendor.",
           "vendor.boot.",
       }) {
    // Concatenate prefix, part, and suffix, and add the resulting property name
    // to the vector
    props.emplace_back(prefix + part + suffix);
  }

  // Return the vector of generated property names
  return props;
}

// Takes an input string and returns a formatted description string
std::string getFormattedDescription(std::string inputStr) {
  // Split input string by '/' and ':' delimiters and store in a vector
  std::stringstream ss(inputStr);
  std::string token;
  std::vector<std::string> tokens;
  while (std::getline(ss, token, '/')) {
    std::stringstream ss2(token);
    std::string subtoken;
    while (std::getline(ss2, subtoken, ':')) {
      tokens.push_back(subtoken);
    }
  }

  // Extract required elements from vector
  std::string device = tokens[1];
  std::string androidVersion = tokens[3];
  std::string buildId = tokens[4];
  std::string buildNumber = tokens[5];
  std::string buildType = tokens[6];
  std::string buildKey = tokens[7];

  // Format output string
  std::string outputStr = device + "-" + buildType + " " + androidVersion +
                          " " + buildId + " " + buildNumber + " " + buildKey;

  // Return formatted output string
  return outputStr;
}

int main(int argc, char *argv[]) {
  if (__system_properties_init()) {
    return -1;
  }

  if (argc != 2) {
    return -1;
  }

  const auto is_init_stage = strcmp(argv[1], "init") == 0;
  const auto is_boot_completed_stage = strcmp(argv[1], "boot_completed") == 0;

  const auto config = load_config();
  const auto build_description = config.find("BUILD_DESCRIPTION");
  const auto build_fingerprint = config.find("BUILD_FINGERPRINT");
  const auto build_security_patch_date =
      config.find("BUILD_SECURITY_PATCH_DATE");
  const auto build_tags = config.find("BUILD_TAGS");
  const auto build_type = config.find("BUILD_TYPE");
  const auto build_version_release = config.find("BUILD_VERSION_RELEASE");
  const auto build_version_release_or_codename =
      config.find("BUILD_VERSION_RELEASE_OR_CODENAME");
  const auto debuggable = config.find("DEBUGGABLE");
  const auto force_basic_attestation = config.find("FORCE_BASIC_ATTESTATION");
  const auto manufacturer_name = config.find("MANUFACTURER_NAME");
  const auto product_brand = config.find("PRODUCT_BRAND");
  const auto product_device = config.find("PRODUCT_DEVICE");
  const auto product_first_api_level = config.find("PRODUCT_FIRST_API_LEVEL");
  const auto product_model = config.find("PRODUCT_MODEL");
  const auto product_name = config.find("PRODUCT_NAME");
  const auto vendor_security_patch_date =
      config.find("VENDOR_SECURITY_PATCH_DATE");

  if (is_init_stage) {
    if (build_fingerprint != config.end()) {
      property_override(property_list("ro.", "build.fingerprint"),
                        build_fingerprint->second.c_str());
    }

    if (build_tags != config.end()) {
      property_override(property_list("ro.", "build.tags"),
                        build_tags->second.c_str());
    } else {
      property_override(property_list("ro.", "build.tags"), "release-keys");
    }

    if (build_type != config.end()) {
      property_override(property_list("ro.", "build.type"),
                        build_type->second.c_str());
    } else {
      property_override(property_list("ro.", "build.type"), "user");
    }

    if (build_description != config.end()) {
      property_override("ro.build.description",
                        build_description->second.c_str());
    } else if (build_fingerprint != config.end()) {
      property_override(
          "ro.build.description",
          getFormattedDescription(build_fingerprint->second).c_str());
    }

    if (debuggable != config.end()) {
      property_override("ro.debuggable", debuggable->second.c_str());
    } else {
      property_override("ro.debuggable", "0");
    }

    if (manufacturer_name != config.end()) {
      property_override(property_list("ro.product.", "manufacturer"),
                        manufacturer_name->second.c_str());
    }

    if (product_brand != config.end()) {
      property_override(property_list("ro.product.", "brand"),
                        product_brand->second.c_str());
    }

    if (product_name != config.end()) {
      property_override(property_list("ro.product.", "name"),
                        product_name->second.c_str());
    }

    if (product_device != config.end()) {
      property_override(property_list("ro.product.", "device"),
                        product_device->second.c_str());
    }

    if (force_basic_attestation == config.end() ||
        (force_basic_attestation != config.end() &&
         force_basic_attestation->second == "1")) {
      const auto &product =
          product_model != config.end() ? product_model : product_device;
      auto pi = (prop_info *)__system_property_find("ro.build.version.release");
      if (pi != nullptr) {
        char android_release[PROP_VALUE_MAX];
        __system_property_read(pi, nullptr, android_release);
        int android_version = std::atoi(android_release);
        if (product != config.end() && android_version >= 12) {
          std::string model = product->second + " ";
          property_override(property_list("ro.product.", "model"),
                            model.c_str());
        } else if (android_version >= 12) {
          auto pi = (prop_info *)__system_property_find("ro.product.model");
          if (pi != nullptr) {
            char value[PROP_VALUE_MAX];
            __system_property_read(pi, nullptr, value);
            strcat(value, " ");
            property_override(property_list("ro.product.", "model"), value);
          }
        }
      }
    } else if (product_model != config.end()) {
      property_override(property_list("ro.product.", "model"),
                        product_model->second.c_str());
    }

    property_override("ro.secure", "1");
  }

  if (is_boot_completed_stage) {
    if (build_version_release != config.end()) {
      property_override(property_list("ro.", "build.version.release"),
                        build_version_release->second.c_str());
    }

    if (build_version_release_or_codename != config.end()) {
      property_override(
          property_list("ro.", "build.version.release_or_codename"),
          build_version_release_or_codename->second.c_str());
    }

    if (build_security_patch_date != config.end()) {
      property_override("ro.build.version.security_patch",
                        build_security_patch_date->second.c_str());
    } else if (build_fingerprint == config.end()) {
      auto pi =
          (prop_info *)__system_property_find("ro.vendor.build.security_patch");
      if (pi != nullptr) {
        char vendor_security_patch[PROP_VALUE_MAX];
        __system_property_read(pi, nullptr, vendor_security_patch);
        property_override("ro.build.version.security_patch",
                          vendor_security_patch);
      }
    }

    if (vendor_security_patch_date != config.end()) {
      property_override("ro.vendor.build.security_patch",
                        vendor_security_patch_date->second.c_str());
    }

    if (product_first_api_level != config.end()) {
      property_override(property_list("ro.", "first_api_level"),
                        product_first_api_level->second.c_str());
      property_override("ro.vendor.api_level",
                        product_first_api_level->second.c_str());
    } else if (force_basic_attestation == config.end() ||
               (force_basic_attestation != config.end() &&
                force_basic_attestation->second == "1")) {
      auto pi =
          (prop_info *)__system_property_find("ro.product.first_api_level");
      if (pi != nullptr) {
        char first_api_level[PROP_VALUE_MAX];
        __system_property_read(pi, nullptr, first_api_level);
        int api_level = std::atoi(first_api_level);
        if (api_level >= 33) {
          property_override(property_list("ro.", "first_api_level"), "32");
          property_override("ro.vendor.api_level", "32");
        }
      }
    }

    property_override("ro.boot.flash.locked", "1");
    property_override("ro.boot.vbmeta.device_state", "locked");
    property_override("vendor.boot.vbmeta.device_state", "locked");
    property_override("ro.boot.verifiedbootstate", "green");
    property_override("vendor.boot.verifiedbootstate", "green");
    property_override("ro.boot.veritymode", "enforcing");
    property_override("ro.is_ever_orange", "0");
    property_override(property_list("ro.", "warranty_bit"), "0");
  }

  return 0;
}
