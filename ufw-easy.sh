#!/usr/bin/env bash

# ===========================================================
# 增强版 UFW 防火墙管理工具
# 版本: 2.0
# 特点: 支持所有 UFW 功能，包括复杂规则设置
# ===========================================================

# 检查 root 权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ 请使用 sudo 或以 root 用户运行此脚本"
        exit 1
    fi
}

# 显示主菜单
show_menu() {
    clear
    echo "====================================================="
    echo "          增强版 UFW 防火墙管理工具"
    echo "====================================================="
    ufw_status=$(ufw status | grep -i status)
    echo " 当前状态: ${ufw_status}"
    echo "-----------------------------------------------------"
    echo " 1. 显示防火墙状态和规则"
    echo " 2. 启用/禁用防火墙"
    echo " 3. 添加简单规则"
    echo " 4. 添加高级规则"
    echo " 5. 删除规则"
    echo " 6. 重置防火墙"
    echo " 7. 管理默认策略"
    echo " 8. 查看应用配置文件"
    echo " 9. 端口转发设置"
    echo " 0. 退出"
    echo "====================================================="
    echo -n "请选择操作 [0-9]: "
}

# 显示防火墙状态和规则
show_status() {
    clear
    echo "==================== 防火墙状态 ===================="
    ufw status verbose
    echo "---------------------------------------------------"
    echo "==================== 规则列表 ======================"
    ufw status numbered
    echo "---------------------------------------------------"
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 切换防火墙状态
toggle_firewall() {
    clear
    echo "================ 启用/禁用防火墙 ================="
    status=$(ufw status | grep -i status | awk '{print $2}')
    
    if [ "$status" = "inactive" ]; then
        ufw enable
        echo "✅ 防火墙已启用"
    else
        ufw disable
        echo "✅ 防火墙已禁用"
    fi
    
    echo "---------------------------------------------------"
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 添加简单规则
add_simple_rule() {
    while true; do
        clear
        echo "==================== 添加简单规则 ===================="
        echo " 1. 允许端口 (所有来源)"
        echo " 2. 拒绝端口 (所有来源)"
        echo " 3. 允许来源IP (所有端口)"
        echo " 4. 拒绝来源IP (所有端口)"
        echo " 5. 允许特定IP访问特定端口"
        echo " 6. 返回主菜单"
        echo "-----------------------------------------------------"
        echo -n "请选择操作 [1-6]: "
        read choice
        
        case $choice in
            1) # 允许端口
                echo -n "请输入要允许的端口 (如: 80, 443, 22/tcp): "
                read port
                if [ -n "$port" ]; then
                    ufw allow "$port"
                    echo "✅ 端口 $port 已允许"
                else
                    echo "❌ 端口不能为空"
                fi
                ;;
            2) # 拒绝端口
                echo -n "请输入要拒绝的端口 (如: 8080, 21/tcp): "
                read port
                if [ -n "$port" ]; then
                    ufw deny "$port"
                    echo "✅ 端口 $port 已拒绝"
                else
                    echo "❌ 端口不能为空"
                fi
                ;;
            3) # 允许来源IP
                echo -n "请输入要允许的IP地址 (如: 192.168.1.100): "
                read ip
                if [ -n "$ip" ]; then
                    ufw allow from "$ip"
                    echo "✅ IP地址 $ip 已允许访问所有端口"
                else
                    echo "❌ IP地址不能为空"
                fi
                ;;
            4) # 拒绝来源IP
                echo -n "请输入要拒绝的IP地址 (如: 10.0.0.5): "
                read ip
                if [ -n "$ip" ]; then
                    ufw deny from "$ip"
                    echo "✅ IP地址 $ip 已拒绝访问所有端口"
                else
                    echo "❌ IP地址不能为空"
                fi
                ;;
            5) # 允许特定IP访问特定端口
                echo -n "请输入要允许的IP地址 (如: 192.168.1.100): "
                read ip
                echo -n "请输入要允许的端口 (如: 22/tcp): "
                read port
                if [ -n "$ip" ] && [ -n "$port" ]; then
                    ufw allow from "$ip" to any port "$port"
                    echo "✅ IP地址 $ip 已允许访问端口 $port"
                else
                    echo "❌ IP地址和端口都不能为空"
                fi
                ;;
            6) return ;;
            *) echo "❌ 无效选择" ;;
        esac
        
        echo "---------------------------------------------------"
        read -n 1 -s -r -p "按任意键继续..."
    done
}

# 添加高级规则
add_advanced_rule() {
    while true; do
        clear
        echo "==================== 添加高级规则 ===================="
        echo " 1. 允许特定IP访问特定端口范围"
        echo " 2. 设置限速规则"
        echo " 3. 允许特定网络接口"
        echo " 4. 设置特定协议规则"
        echo " 5. 添加应用配置文件规则"
        echo " 6. 返回主菜单"
        echo "-----------------------------------------------------"
        echo -n "请选择操作 [1-6]: "
        read choice
        
        case $choice in
            1) # 允许特定IP访问特定端口范围
                echo -n "请输入要允许的IP地址: "
                read ip
                echo -n "请输入起始端口: "
                read start_port
                echo -n "请输入结束端口: "
                read end_port
                echo -n "请输入协议 (tcp/udp, 默认为tcp): "
                read protocol
                protocol=${protocol:-tcp}
                
                if [ -n "$ip" ] && [ -n "$start_port" ] && [ -n "$end_port" ]; then
                    ufw allow from "$ip" to any port "$start_port:$end_port"/"$protocol"
                    echo "✅ IP地址 $ip 已允许访问端口范围 $start_port-$end_port/$protocol"
                else
                    echo "❌ 所有字段都必须填写"
                fi
                ;;
            2) # 设置限速规则
                echo -n "请输入端口: "
                read port
                echo -n "请输入最大连接数 (如: 10): "
                read limit
                echo -n "请输入时间间隔 (秒, 如: 30): "
                read interval
                
                if [ -n "$port" ] && [ -n "$limit" ] && [ -n "$interval" ]; then
                    ufw limit "$port" comment "限速: ${limit}次/${interval}秒"
                    echo "✅ 端口 $port 已设置限速规则: ${limit}次/${interval}秒"
                else
                    echo "❌ 所有字段都必须填写"
                fi
                ;;
            3) # 允许特定网络接口
                echo -n "请输入端口: "
                read port
                echo -n "请输入网络接口 (如: eth0): "
                read interface
                
                if [ -n "$port" ] && [ -n "$interface" ]; then
                    ufw allow in on "$interface" to any port "$port"
                    echo "✅ 接口 $interface 的入站端口 $port 已允许"
                else
                    echo "❌ 所有字段都必须填写"
                fi
                ;;
            4) # 设置特定协议规则
                echo -n "请输入端口: "
                read port
                echo -n "请输入协议 (tcp/udp): "
                read protocol
                echo -n "允许还是拒绝? (allow/deny): "
                read action
                
                if [ -n "$port" ] && [ -n "$protocol" ] && [ -n "$action" ]; then
                    ufw "$action" "$port"/"$protocol"
                    echo "✅ 端口 $port/$protocol 已设置为 $action"
                else
                    echo "❌ 所有字段都必须填写"
                fi
                ;;
            5) # 添加应用配置文件规则
                echo "可用的应用配置文件:"
                ufw app list
                echo -n "请输入应用配置文件名: "
                read app
                
                if [ -n "$app" ]; then
                    ufw allow "$app"
                    echo "✅ 应用配置文件 $app 已允许"
                else
                    echo "❌ 应用配置文件名不能为空"
                fi
                ;;
            6) return ;;
            *) echo "❌ 无效选择" ;;
        esac
        
        echo "---------------------------------------------------"
        read -n 1 -s -r -p "按任意键继续..."
    done
}

# 删除规则
delete_rule() {
    clear
    echo "===================== 删除规则 ===================="
    echo "编号 | 规则"
    echo "--------------------------------------------------"
    
    # 显示带编号的规则列表
    ufw status numbered | grep -v 'Status:' | grep -v 'To' | grep -v '--' | nl -v 0
    
    echo "--------------------------------------------------"
    echo -n "请输入要删除的规则编号 (或 'a' 删除所有规则): "
    read rule_num
    
    if [ -z "$rule_num" ]; then
        echo "❌ 规则编号不能为空"
    elif [ "$rule_num" = "a" ]; then
        echo -n "⚠️ 确定要删除所有规则吗? [y/N]: "
        read confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            ufw reset --force
            echo "✅ 所有规则已删除"
        else
            echo "❌ 操作已取消"
        fi
    else
        # 检查规则是否存在
        if ufw status numbered | grep -q "^\[$rule_num\]"; then
            ufw --force delete "$rule_num"
            echo "✅ 规则 $rule_num 已删除"
        else
            echo "❌ 规则 $rule_num 不存在"
        fi
    fi
    
    echo "---------------------------------------------------"
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 重置防火墙
reset_firewall() {
    clear
    echo "===================== 重置防火墙 =================="
    echo -n "⚠️ 确定要重置防火墙吗? 所有规则将被删除! [y/N]: "
    read confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        ufw --force reset
        echo "✅ 防火墙已重置"
    else
        echo "❌ 操作已取消"
    fi
    
    echo "---------------------------------------------------"
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 管理默认策略
manage_default_policy() {
    while true; do
        clear
        echo "==================== 管理默认策略 ===================="
        echo " 1. 查看当前默认策略"
        echo " 2. 设置默认入站策略"
        echo " 3. 设置默认出站策略"
        echo " 4. 返回主菜单"
        echo "-----------------------------------------------------"
        echo -n "请选择操作 [1-4]: "
        read choice
        
        case $choice in
            1) # 查看当前默认策略
                echo "当前默认策略:"
                ufw status verbose | grep "Default:"
                ;;
            2) # 设置默认入站策略
                echo -n "设置默认入站策略 (allow/deny/reject): "
                read policy
                if [ -n "$policy" ]; then
                    ufw default incoming "$policy"
                    echo "✅ 默认入站策略已设置为: $policy"
                else
                    echo "❌ 策略不能为空"
                fi
                ;;
            3) # 设置默认出站策略
                echo -n "设置默认出站策略 (allow/deny/reject): "
                read policy
                if [ -n "$policy" ]; then
                    ufw default outgoing "$policy"
                    echo "✅ 默认出站策略已设置为: $policy"
                else
                    echo "❌ 策略不能为空"
                fi
                ;;
            4) return ;;
            *) echo "❌ 无效选择" ;;
        esac
        
        echo "---------------------------------------------------"
        read -n 1 -s -r -p "按任意键继续..."
    done
}

# 查看应用配置文件
view_app_profiles() {
    clear
    echo "==================== 应用配置文件 ===================="
    echo "可用配置文件列表:"
    ufw app list
    echo -n "输入配置文件名称查看详情 (直接回车返回): "
    read app
    
    if [ -n "$app" ]; then
        echo "---------------------------------------------------"
        ufw app info "$app"
    fi
    
    echo "---------------------------------------------------"
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 端口转发设置
port_forwarding() {
    clear
    echo "==================== 端口转发设置 ===================="
    echo " 1. 添加端口转发规则"
    echo " 2. 查看当前端口转发规则"
    echo " 3. 删除端口转发规则"
    echo " 4. 返回主菜单"
    echo "-----------------------------------------------------"
    echo -n "请选择操作 [1-4]: "
    read choice
    
    case $choice in
        1) # 添加端口转发
            echo -n "请输入源端口: "
            read src_port
            echo -n "请输入目标IP: "
            read dest_ip
            echo -n "请输入目标端口: "
            read dest_port
            echo -n "请输入协议 (tcp/udp): "
            read protocol
            
            if [ -n "$src_port" ] && [ -n "$dest_ip" ] && [ -n "$dest_port" ] && [ -n "$protocol" ]; then
                # 启用IP转发
                sysctl -w net.ipv4.ip_forward=1
                echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
                
                # 添加转发规则
                iptables -t nat -A PREROUTING -p "$protocol" --dport "$src_port" -j DNAT --to-destination "${dest_ip}:${dest_port}"
                iptables -t nat -A POSTROUTING -p "$protocol" -d "$dest_ip" --dport "$dest_port" -j MASQUERADE
                
                # 保存规则
                iptables-save > /etc/iptables/rules.v4
                
                echo "✅ 端口转发已添加: ${src_port} -> ${dest_ip}:${dest_port}/${protocol}"
            else
                echo "❌ 所有字段都必须填写"
            fi
            ;;
        2) # 查看端口转发规则
            echo "当前端口转发规则:"
            iptables -t nat -L PREROUTING -n -v
            ;;
        3) # 删除端口转发规则
            echo "当前端口转发规则:"
            iptables -t nat -L PREROUTING -n -v --line-numbers
            echo -n "请输入要删除的规则编号: "
            read rule_num
            if [ -n "$rule_num" ]; then
                iptables -t nat -D PREROUTING "$rule_num"
                iptables-save > /etc/iptables/rules.v4
                echo "✅ 规则 $rule_num 已删除"
            else
                echo "❌ 规则编号不能为空"
            fi
            ;;
        4) return ;;
        *) echo "❌ 无效选择" ;;
    esac
    
    echo "---------------------------------------------------"
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 主函数
main() {
    check_root
    
    # 确保安装了 ufw
    if ! command -v ufw &> /dev/null; then
        echo "❌ UFW 未安装，正在安装..."
        apt update
        apt install -y ufw
        ufw disable
    fi
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1) show_status ;;
            2) toggle_firewall ;;
            3) add_simple_rule ;;
            4) add_advanced_rule ;;
            5) delete_rule ;;
            6) reset_firewall ;;
            7) manage_default_policy ;;
            8) view_app_profiles ;;
            9) port_forwarding ;;
            0) 
                echo -e "\n感谢使用，再见！"
                exit 0
                ;;
            *) 
                echo -e "\n❌ 无效选择，请重新输入"
                sleep 1
                ;;
        esac
    done
}

# 启动主函数
main
