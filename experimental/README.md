# 🧪 Experimental Directory

**This directory contains experimental data, firmware dumps, and analysis results.**

## 📁 Directory Structure

```
experimental/
├── README.md              # This file
├── dsdt/                  # ACPI DSDT dumps and analysis
├── firmware/              # Firmware dumps and analysis
├── kernel_modules/        # Custom kernel module attempts
├── ec_dumps/              # Embedded controller dumps
└── analysis/              # Analysis results and findings
```

## 🔬 What Goes Here

### ACPI DSDT Analysis
- Raw DSDT table dumps (`dsdt_table.dat`)
- Decompiled DSDT files (`dsdt_table.dsl`)
- ACPI method analysis results
- Fan-related ACPI method discoveries

### Firmware Dumps
- DMIDecode outputs
- BIOS information dumps
- Embedded controller firmware analysis
- System management interface dumps

### Kernel Module Experiments
- Custom kernel module source code
- Modified dell-smm-hwmon attempts
- i8k module modifications
- Experimental fan control modules

### EC (Embedded Controller) Analysis
- Direct EC port access attempts
- EC communication protocol analysis
- EC response logs and analysis
- EC bypass method attempts

### Analysis Results
- Reverse engineering findings
- Protocol analysis results
- Bypass method documentation
- Technical analysis reports

## 📋 Usage Guidelines

### Adding New Experiments
1. **Create appropriate subdirectory** for your experiment type
2. **Document your experiment** with a README file
3. **Include raw data** and analysis results
4. **Update findings.md** with your discoveries

### File Naming Convention
- Use descriptive names: `m18_dsdt_analysis_2024-01-15.txt`
- Include date and model information
- Use consistent file extensions
- Document file contents in README

### Data Organization
- Keep raw dumps separate from analysis
- Use consistent directory structure
- Document all assumptions and methods
- Include error logs and debugging info

## 🔍 Current Experiments

### Planned Experiments
- [ ] DSDT decompilation and analysis
- [ ] EC port access testing
- [ ] Custom kernel module development
- [ ] ACPI method reverse engineering
- [ ] Firmware modification attempts

### Active Experiments
- [ ] Basic system dumps
- [ ] Initial EC probe results
- [ ] Kernel module parameter testing

### Completed Experiments
- [ ] Initial system baseline
- [ ] Basic PWM interface testing

## ⚠️ Safety Notes

### Hardware Safety
- **Never modify firmware** without proper backup
- **Test in controlled environment** first
- **Monitor system temperatures** during experiments
- **Have recovery plan** ready

### Data Safety
- **Backup all original data** before modification
- **Document all changes** made to system
- **Keep original firmware copies** safe
- **Test on non-critical systems** first

## 📚 Analysis Tools

### Required Tools
- `iasl` - ACPI compiler/decompiler
- `dmidecode` - DMI table decoder
- `hexdump` - Binary data analysis
- `objdump` - Object file analysis

### Recommended Tools
- `xxd` - Hex dump utility
- `strings` - String extraction
- `grep` - Pattern searching
- `diff` - File comparison

### Analysis Workflow
1. **Extract raw data** using appropriate tools
2. **Decompile/analyze** using specialized tools
3. **Search for patterns** related to fan control
4. **Document findings** in analysis files
5. **Update project documentation** with discoveries

## 🤝 Contributing

### Adding New Experiments
1. **Create experiment directory** with descriptive name
2. **Add README.md** explaining the experiment
3. **Include all raw data** and analysis results
4. **Update this README** with experiment details
5. **Report findings** in main project documentation

### Sharing Results
- **Use consistent format** for all experiments
- **Include system information** with all results
- **Document all commands** used in experiments
- **Share both successes and failures**
- **Update status tracking** in main documentation

---

**Remember: Every experiment, successful or not, brings us closer to unlocking fan control! 🔥** 