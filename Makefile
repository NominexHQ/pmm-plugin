# Makefile — pmm-plugin local skill generator
# Reads plugin skills/ and generates cached local variants in local/.
# Transform: pmm: → pmm- (name, body refs, slash invocations, frontmatter).

PLUGIN_ROOT := $(shell pwd)
SKILLS_DIR  := $(PLUGIN_ROOT)/skills
LOCAL_DIR   := $(PLUGIN_ROOT)/local

# Skills to transform (all dirs in skills/ containing SKILL.md)
# Exclude init-local-skills — it's a meta-skill (installs the others), no local variant needed.
SKILL_DIRS := $(wildcard $(SKILLS_DIR)/*/SKILL.md)
SKILL_NAMES := $(filter-out init-local-skills,$(notdir $(patsubst %/SKILL.md,%,$(SKILL_DIRS))))

.PHONY: local clean

local:
	@echo "Generating local skill variants..."
	@mkdir -p "$(LOCAL_DIR)"
	@for skill in $(SKILL_NAMES); do \
		src="$(SKILLS_DIR)/$$skill/SKILL.md"; \
		dash_name="pmm-$$skill"; \
		dest_dir="$(LOCAL_DIR)/$$dash_name"; \
		mkdir -p "$$dest_dir"; \
		$(PLUGIN_ROOT)/scripts/transform.sh "$$src" "$$dest_dir/SKILL.md" "$$dash_name" "$$skill"; \
		if [ -d "$(SKILLS_DIR)/$$skill/assets" ]; then \
			cp -r "$(SKILLS_DIR)/$$skill/assets" "$$dest_dir/"; \
		fi; \
	done
	@echo "Done. $(words $(SKILL_NAMES)) skills generated in local/"

clean:
	rm -rf "$(LOCAL_DIR)"
	@echo "Cleaned local/"
