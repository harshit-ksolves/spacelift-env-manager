#!/bin/bash

# Generic Spacelift Environment Variables Setup Script
# This script helps add environment variables to Spacelift stacks using spacectl

set -e

function show_help() {
    echo "Generic Spacelift Environment Variables Setup Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  add-vars STACK_ID ENV_FILE    Add variables from ENV_FILE to STACK_ID"
    echo "  list-stacks                   List all available stacks"
    echo "  list-files                    List available .env files"
    echo "  validate-file ENV_FILE        Validate .env file format"
    echo ""
    echo "Examples:"
    echo "  $0 add-vars my-stack-id variables.env"
    echo "  $0 add-vars my-context-id ebt-template.env"
    echo "  $0 list-stacks"
    echo "  $0 list-files"
    echo ""
    echo "Prerequisites:"
    echo "  - spacectl must be installed and configured"
    echo "  - You must be logged in: spacectl profile login"
    echo "  - Stack/Context must exist in Spacelift"
    echo ""
}

function check_prerequisites() {
    # Check if spacectl is available
    if ! command -v spacectl &> /dev/null; then
        echo "❌ Error: spacectl is not installed"
        echo "Install with: curl -fsSL https://downloads.spacelift.io/spacectl | sudo sh"
        exit 1
    fi
    
    # Check if user is logged in
    if ! spacectl whoami &> /dev/null; then
        echo "❌ Error: Not logged in to Spacelift"
        echo "Please login: spacectl profile login"
        exit 1
    fi
}

function validate_env_file() {
    local env_file="$1"
    
    if [ ! -f "$env_file" ]; then
        echo "❌ Error: Environment file '$env_file' not found"
        return 1
    fi
    
    echo "🔍 Validating environment file: $env_file"
    
    local total_lines=0
    local valid_lines=0
    local comment_lines=0
    local empty_lines=0
    local invalid_lines=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        total_lines=$((total_lines + 1))
        
        # Skip empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
            empty_lines=$((empty_lines + 1))
            continue
        fi
        
        # Skip comment lines
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            comment_lines=$((comment_lines + 1))
            continue
        fi
        
        # Check if line has valid key=value format
        if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
            valid_lines=$((valid_lines + 1))
        else
            invalid_lines=$((invalid_lines + 1))
            echo "⚠️  Invalid line $total_lines: $line"
        fi
        
    done < "$env_file"
    
    echo "📊 File validation summary:"
    echo "   Total lines: $total_lines"
    echo "   Valid variables: $valid_lines"
    echo "   Comments: $comment_lines"
    echo "   Empty lines: $empty_lines"
    echo "   Invalid lines: $invalid_lines"
    echo ""
    
    if [ $invalid_lines -gt 0 ]; then
        echo "⚠️  File has some invalid lines but processing will continue"
        echo "   Only valid key=value lines will be processed"
    else
        echo "✅ File format is valid"
    fi
    
    return 0
}

function add_variables_to_stack() {
    local stack_id="$1"
    local env_file="$2"
    
    if [ -z "$stack_id" ] || [ -z "$env_file" ]; then
        echo "❌ Error: Both STACK_ID and ENV_FILE are required"
        echo "Usage: $0 add-vars STACK_ID ENV_FILE"
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Validate environment file
    if ! validate_env_file "$env_file"; then
        exit 1
    fi
    
    echo "🚀 Adding variables to Spacelift stack/context: $stack_id"
    echo "📁 Using variables from: $env_file"
    echo ""
    
    local variable_count=0
    local success_count=0
    local error_count=0
    local secret_count=0
    
    # Read variables file and add each variable
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip empty lines and comments
        if [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Clean up key and value
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Skip if key is empty after cleaning
        if [[ -z "$key" ]]; then
            continue
        fi
        
        # Remove quotes if present around value
        if [[ "$value" =~ ^\".*\"$ ]]; then
            value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
        fi
        
        # Check if should be secret (configurable keywords)
        write_only=""
        is_secret=false
        if [[ "$key" =~ (password) ]]; then
            write_only="--write-only"
            is_secret=true
            secret_count=$((secret_count + 1))
            echo "🔒 Adding secret variable: $key"
        else
            echo "📝 Adding variable: $key"
        fi
        
        variable_count=$((variable_count + 1))
        
        # Add variable using spacectl
        if spacectl stack environment setvar --id "$stack_id" $write_only "$key" "$value" 2>/dev/null; then
            echo "   ✅ Success"
            success_count=$((success_count + 1))
        else
            echo "   ❌ Failed (may already exist or insufficient permissions)"
            error_count=$((error_count + 1))
        fi
        
    done < "$env_file"
    
    echo ""
    echo "📊 Import Summary:"
    echo "   Total variables processed: $variable_count"
    echo "   Successfully added: $success_count"
    echo "   Failed/Skipped: $error_count"
    echo "   Marked as secret: $secret_count"
    echo ""
    
    if [ $error_count -gt 0 ]; then
        echo "⚠️  Some variables failed to import. This could be due to:"
        echo "   - Variables already exist (duplicates)"
        echo "   - Insufficient permissions"
        echo "   - Invalid stack/context ID"
        echo "   - Network issues"
        echo ""
        echo "💡 Check the Spacelift UI to verify which variables were added"
    fi
    
    if [ $success_count -gt 0 ]; then
        echo "🎉 Successfully imported $success_count variables!"
        echo "🔗 View in Spacelift: https://app.spacelift.io/stacks/$stack_id"
    fi
}

function list_stacks() {
    echo "📋 Available Stacks in Spacelift:"
    echo "================================="
    
    check_prerequisites
    
    if spacectl stack list --output table 2>/dev/null; then
        echo ""
        echo "💡 Use the 'ID' column value as STACK_ID parameter"
    else
        echo "❌ Failed to list stacks. Check your permissions and login status."
        exit 1
    fi
}

function list_env_files() {
    echo "📁 Available .env files in current directory:"
    echo "=============================================="
    
    local env_files=(*.env)
    
    if [ ${#env_files[@]} -eq 1 ] && [ ! -f "${env_files[0]}" ]; then
        echo "❌ No .env files found in current directory"
        echo ""
        echo "💡 Create .env files with this format:"
        echo "   TF_VAR_variable_name=value"
        echo "   TF_VAR_another_var=another_value"
        return 1
    fi
    
    for file in "${env_files[@]}"; do
        if [ -f "$file" ]; then
            local size=$(du -h "$file" | cut -f1)
            local lines=$(wc -l < "$file" 2>/dev/null || echo "?")
            echo "📄 $file ($size, $lines lines)"
        fi
    done
    
    echo ""
    echo "💡 Use any of these files as ENV_FILE parameter"
    echo "💡 Run '$0 validate-file FILENAME' to check format"
}

# Main script logic
case "${1:-help}" in
    "add-vars")
        if [ $# -ne 3 ]; then
            echo "❌ Error: Incorrect number of arguments"
            echo "Usage: $0 add-vars STACK_ID ENV_FILE"
            echo ""
            echo "Examples:"
            echo "  $0 add-vars my-stack-name variables.env"
            echo "  $0 add-vars ctx-12345 production.env"
            echo ""
            list_stacks
            echo ""
            list_env_files
            exit 1
        fi
        add_variables_to_stack "$2" "$3"
        ;;
    "list-stacks")
        list_stacks
        ;;
    "list-files")
        list_env_files
        ;;
    "validate-file")
        if [ -z "$2" ]; then
            echo "❌ Error: ENV_FILE required"
            echo "Usage: $0 validate-file ENV_FILE"
            exit 1
        fi
        validate_env_file "$2"
        ;;
    "help"|*)
        show_help
        ;;
esac 
