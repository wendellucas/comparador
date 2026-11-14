# Comparador de Arquivos por Hash (Interface Visual WPF)
# Permite arrastar e soltar (Drag & Drop) dois arquivos para comparar seus hashes.

# Garante execucao em modo STA (necessario para WPF)
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $powershellExe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $powershellExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`"" -WindowStyle Hidden
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Comparador de Arquivos por Hash"
        Width="920" Height="640"
        MinWidth="760" MinHeight="560"
        WindowStartupLocation="CenterScreen"
        Background="#0F172A"
        Foreground="#F8FAFC"
        FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Estilo de Botoes Padrao -->
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#334155"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#475569"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#0F172A"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo de Botao Primario -->
        <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#2563EB"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#3B82F6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1D4ED8"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#60A5FA"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1E40AF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- CABECALHO -->
        <Grid Grid.Row="0" Margin="0,0,0,18">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0">
                <TextBlock Text="Comparador de Arquivos por Hash"
                           FontSize="22"
                           FontWeight="Bold"
                           Foreground="#F8FAFC"/>
                <TextBlock Text="Arraste e solte os arquivos nas áreas abaixo (ou clique nelas) para verificar se são idênticos"
                           FontSize="13"
                           Foreground="#94A3B8"
                           Margin="0,4,0,0"/>
            </StackPanel>

            <!-- Seletor de Algoritmo -->
            <Border Grid.Column="1"
                    Background="#1E293B"
                    BorderBrush="#334155"
                    BorderThickness="1"
                    CornerRadius="8"
                    Padding="12,8"
                    VerticalAlignment="Center">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="Algoritmo:"
                               Foreground="#94A3B8"
                               FontSize="13"
                               FontWeight="SemiBold"
                               VerticalAlignment="Center"
                               Margin="0,0,10,0"/>
                    <ComboBox x:Name="CmbAlgorithm"
                              Width="115"
                              FontSize="13"
                              FontWeight="SemiBold"
                              SelectedIndex="0"
                              VerticalContentAlignment="Center">
                        <ComboBoxItem Content="SHA256"/>
                        <ComboBoxItem Content="MD5"/>
                        <ComboBoxItem Content="SHA1"/>
                        <ComboBoxItem Content="SHA512"/>
                    </ComboBox>
                </StackPanel>
            </Border>
        </Grid>

        <!-- AREAS DE DRAG & DROP (LADO A LADO) -->
        <Grid Grid.Row="1" Margin="0,0,0,18">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="18"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- CARD ARQUIVO 1 -->
            <Grid Grid.Column="0"
                  x:Name="DropZone1"
                  AllowDrop="True"
                  Background="#1E293B"
                  Cursor="Hand">
                <Border x:Name="BorderZone1"
                        Background="#1E293B"
                        CornerRadius="12"
                        BorderBrush="#334155"
                        BorderThickness="1"/>
                <Rectangle x:Name="DashRect1"
                           Stroke="#475569"
                           StrokeThickness="2"
                           StrokeDashArray="5,3"
                           RadiusX="12"
                           RadiusY="12"
                           Margin="6"/>

                <Grid Margin="22">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Topo do Card 1 -->
                    <Grid Grid.Row="0">
                        <Border Background="#0F172A"
                                CornerRadius="6"
                                Padding="10,4"
                                HorizontalAlignment="Left">
                            <TextBlock Text="ARQUIVO 1"
                                       FontSize="11.5"
                                       FontWeight="Bold"
                                       Foreground="#38BDF8"/>
                        </Border>
                        <Button x:Name="BtnSelect1"
                                Content="Procurar..."
                                Style="{StaticResource ModernButton}"
                                Padding="10,4"
                                FontSize="11.5"
                                HorizontalAlignment="Right"/>
                    </Grid>

                    <!-- Conteudo Central Card 1 -->
                    <StackPanel Grid.Row="1"
                                VerticalAlignment="Center"
                                HorizontalAlignment="Center"
                                Margin="10,16">
                        <Border x:Name="IconBadge1"
                                Width="56" Height="56"
                                CornerRadius="28"
                                Background="#0F172A"
                                BorderBrush="#334155"
                                BorderThickness="1"
                                HorizontalAlignment="Center"
                                Margin="0,0,0,12">
                            <TextBlock x:Name="IconText1"
                                       Text="📥"
                                       FontSize="24"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                        </Border>

                        <TextBlock x:Name="TxtFileName1"
                                   Text="Arraste o 1º arquivo aqui"
                                   FontSize="16"
                                   FontWeight="Bold"
                                   Foreground="#F1F5F9"
                                   TextAlignment="Center"
                                   TextTrimming="CharacterEllipsis"
                                   MaxWidth="360"/>

                        <TextBlock x:Name="TxtFilePath1"
                                   Text="ou clique para selecionar no computador"
                                   FontSize="12"
                                   Foreground="#64748B"
                                   TextAlignment="Center"
                                   TextTrimming="CharacterEllipsis"
                                   MaxWidth="360"
                                   Margin="0,5,0,0"/>

                        <Border x:Name="BadgeInfo1"
                                Background="#0F172A"
                                CornerRadius="6"
                                Padding="10,4"
                                Margin="0,10,0,0"
                                HorizontalAlignment="Center"
                                Visibility="Collapsed">
                            <TextBlock x:Name="TxtFileMeta1"
                                       Text=""
                                       FontSize="11.5"
                                       Foreground="#94A3B8"/>
                        </Border>
                    </StackPanel>

                    <!-- Area de Hash Card 1 -->
                    <StackPanel Grid.Row="2">
                        <Grid Margin="0,0,0,6">
                            <TextBlock Text="HASH DO ARQUIVO"
                                       FontSize="11"
                                       FontWeight="Bold"
                                       Foreground="#64748B"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="BtnCopy1"
                                    Content="Copiar Hash"
                                    Style="{StaticResource ModernButton}"
                                    Padding="8,2"
                                    FontSize="11"
                                    HorizontalAlignment="Right"
                                    IsEnabled="False"/>
                        </Grid>
                        <Border Background="#0F172A"
                                BorderBrush="#334155"
                                BorderThickness="1"
                                CornerRadius="6"
                                Padding="10,8">
                            <TextBox x:Name="TxtHash1"
                                     Text="Nenhum arquivo selecionado"
                                     FontFamily="Consolas"
                                     FontSize="12"
                                     Foreground="#64748B"
                                     Background="Transparent"
                                     BorderThickness="0"
                                     IsReadOnly="True"
                                     TextWrapping="Wrap"/>
                        </Border>
                    </StackPanel>
                </Grid>
            </Grid>

            <!-- CARD ARQUIVO 2 -->
            <Grid Grid.Column="2"
                  x:Name="DropZone2"
                  AllowDrop="True"
                  Background="#1E293B"
                  Cursor="Hand">
                <Border x:Name="BorderZone2"
                        Background="#1E293B"
                        CornerRadius="12"
                        BorderBrush="#334155"
                        BorderThickness="1"/>
                <Rectangle x:Name="DashRect2"
                           Stroke="#475569"
                           StrokeThickness="2"
                           StrokeDashArray="5,3"
                           RadiusX="12"
                           RadiusY="12"
                           Margin="6"/>

                <Grid Margin="22">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Topo do Card 2 -->
                    <Grid Grid.Row="0">
                        <Border Background="#0F172A"
                                CornerRadius="6"
                                Padding="10,4"
                                HorizontalAlignment="Left">
                            <TextBlock Text="ARQUIVO 2"
                                       FontSize="11.5"
                                       FontWeight="Bold"
                                       Foreground="#A78BFA"/>
                        </Border>
                        <Button x:Name="BtnSelect2"
                                Content="Procurar..."
                                Style="{StaticResource ModernButton}"
                                Padding="10,4"
                                FontSize="11.5"
                                HorizontalAlignment="Right"/>
                    </Grid>

                    <!-- Conteudo Central Card 2 -->
                    <StackPanel Grid.Row="1"
                                VerticalAlignment="Center"
                                HorizontalAlignment="Center"
                                Margin="10,16">
                        <Border x:Name="IconBadge2"
                                Width="56" Height="56"
                                CornerRadius="28"
                                Background="#0F172A"
                                BorderBrush="#334155"
                                BorderThickness="1"
                                HorizontalAlignment="Center"
                                Margin="0,0,0,12">
                            <TextBlock x:Name="IconText2"
                                       Text="📥"
                                       FontSize="24"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                        </Border>

                        <TextBlock x:Name="TxtFileName2"
                                   Text="Arraste o 2º arquivo aqui"
                                   FontSize="16"
                                   FontWeight="Bold"
                                   Foreground="#F1F5F9"
                                   TextAlignment="Center"
                                   TextTrimming="CharacterEllipsis"
                                   MaxWidth="360"/>

                        <TextBlock x:Name="TxtFilePath2"
                                   Text="ou clique para selecionar no computador"
                                   FontSize="12"
                                   Foreground="#64748B"
                                   TextAlignment="Center"
                                   TextTrimming="CharacterEllipsis"
                                   MaxWidth="360"
                                   Margin="0,5,0,0"/>

                        <Border x:Name="BadgeInfo2"
                                Background="#0F172A"
                                CornerRadius="6"
                                Padding="10,4"
                                Margin="0,10,0,0"
                                HorizontalAlignment="Center"
                                Visibility="Collapsed">
                            <TextBlock x:Name="TxtFileMeta2"
                                       Text=""
                                       FontSize="11.5"
                                       Foreground="#94A3B8"/>
                        </Border>
                    </StackPanel>

                    <!-- Area de Hash Card 2 -->
                    <StackPanel Grid.Row="2">
                        <Grid Margin="0,0,0,6">
                            <TextBlock Text="HASH DO ARQUIVO"
                                       FontSize="11"
                                       FontWeight="Bold"
                                       Foreground="#64748B"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="BtnCopy2"
                                    Content="Copiar Hash"
                                    Style="{StaticResource ModernButton}"
                                    Padding="8,2"
                                    FontSize="11"
                                    HorizontalAlignment="Right"
                                    IsEnabled="False"/>
                        </Grid>
                        <Border Background="#0F172A"
                                BorderBrush="#334155"
                                BorderThickness="1"
                                CornerRadius="6"
                                Padding="10,8">
                            <TextBox x:Name="TxtHash2"
                                     Text="Nenhum arquivo selecionado"
                                     FontFamily="Consolas"
                                     FontSize="12"
                                     Foreground="#64748B"
                                     Background="Transparent"
                                     BorderThickness="0"
                                     IsReadOnly="True"
                                     TextWrapping="Wrap"/>
                        </Border>
                    </StackPanel>
                </Grid>
            </Grid>
        </Grid>

        <!-- BANNER DE RESULTADO DA COMPARACAO -->
        <Border Grid.Row="2"
                x:Name="ResultBanner"
                Background="#1E293B"
                BorderBrush="#334155"
                BorderThickness="1.5"
                CornerRadius="10"
                Padding="18,14"
                Margin="0,0,0,16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <TextBlock x:Name="ResultIcon"
                           Grid.Column="0"
                           Text="⚖️"
                           FontSize="26"
                           VerticalAlignment="Center"
                           Margin="0,0,14,0"/>

                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock x:Name="ResultTitle"
                               Text="Aguardando arquivos para comparação"
                               FontSize="15.5"
                               FontWeight="Bold"
                               Foreground="#E2E8F0"/>
                    <TextBlock x:Name="ResultSubtitle"
                               Text="Arraste dois arquivos (individualmente ou os dois juntos de uma vez) para verificar se possuem o mesmo hash."
                               FontSize="12.5"
                               Foreground="#94A3B8"
                               Margin="0,2,0,0"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- RODAPE DE ACOES -->
        <Grid Grid.Row="3">
            <TextBlock Text="Dica: Você também pode selecionar 2 arquivos juntos no Windows Explorer e soltar em qualquer área."
                       FontSize="12"
                       Foreground="#64748B"
                       VerticalAlignment="Center"
                       HorizontalAlignment="Left"/>

            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="BtnClear"
                        Content="Limpar Tudo"
                        Style="{StaticResource ModernButton}"
                        Margin="0,0,10,0"/>
                <Button x:Name="BtnRecalculate"
                        Content="Recomparar Agora"
                        Style="{StaticResource AccentButton}"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Captura dos controles
$CmbAlgorithm   = $window.FindName("CmbAlgorithm")
$DropZone1      = $window.FindName("DropZone1")
$DropZone2      = $window.FindName("DropZone2")
$BorderZone1    = $window.FindName("BorderZone1")
$BorderZone2    = $window.FindName("BorderZone2")
$DashRect1      = $window.FindName("DashRect1")
$DashRect2      = $window.FindName("DashRect2")
$IconBadge1     = $window.FindName("IconBadge1")
$IconBadge2     = $window.FindName("IconBadge2")
$IconText1      = $window.FindName("IconText1")
$IconText2      = $window.FindName("IconText2")
$TxtFileName1   = $window.FindName("TxtFileName1")
$TxtFileName2   = $window.FindName("TxtFileName2")
$TxtFilePath1   = $window.FindName("TxtFilePath1")
$TxtFilePath2   = $window.FindName("TxtFilePath2")
$BadgeInfo1     = $window.FindName("BadgeInfo1")
$BadgeInfo2     = $window.FindName("BadgeInfo2")
$TxtFileMeta1   = $window.FindName("TxtFileMeta1")
$TxtFileMeta2   = $window.FindName("TxtFileMeta2")
$TxtHash1       = $window.FindName("TxtHash1")
$TxtHash2       = $window.FindName("TxtHash2")
$BtnSelect1     = $window.FindName("BtnSelect1")
$BtnSelect2     = $window.FindName("BtnSelect2")
$BtnCopy1       = $window.FindName("BtnCopy1")
$BtnCopy2       = $window.FindName("BtnCopy2")
$ResultBanner   = $window.FindName("ResultBanner")
$ResultIcon     = $window.FindName("ResultIcon")
$ResultTitle    = $window.FindName("ResultTitle")
$ResultSubtitle = $window.FindName("ResultSubtitle")
$BtnClear       = $window.FindName("BtnClear")
$BtnRecalculate = $window.FindName("BtnRecalculate")

# Estado da aplicacao
$script:State = @{
    File1 = $null
    File2 = $null
    Hash1 = $null
    Hash2 = $null
    Size1 = 0L
    Size2 = 0L
}

$brushConverter = New-Object System.Windows.Media.BrushConverter
function Get-Brush([string]$hex) {
    return $brushConverter.ConvertFromString($hex)
}

function Format-FileSize([long]$bytes) {
    if ($bytes -lt 1024) { return "$bytes B" }
    elseif ($bytes -lt 1048576) { return "{0:N2} KB ({1:N0} B)" -f ($bytes / 1KB), $bytes }
    elseif ($bytes -lt 1073741824) { return "{0:N2} MB ({1:N0} B)" -f ($bytes / 1MB), $bytes }
    else { return "{0:N2} GB ({1:N0} B)" -f ($bytes / 1GB), $bytes }
}

function Get-AlgorithmName {
    $selected = $CmbAlgorithm.SelectedItem
    if ($null -ne $selected -and $null -ne $selected.Content) {
        return $selected.Content.ToString()
    }
    return "SHA256"
}

function Compute-FileHashString([string]$filePath, [string]$algorithm) {
    $hashResult = Get-FileHash -LiteralPath $filePath -Algorithm $algorithm -ErrorAction Stop
    return $hashResult.Hash.ToLowerInvariant()
}

function Update-ComparisonBanner {
    $algo = Get-AlgorithmName

    if ([string]::IsNullOrEmpty($script:State.File1) -and [string]::IsNullOrEmpty($script:State.File2)) {
        $ResultBanner.Background = Get-Brush "#1E293B"
        $ResultBanner.BorderBrush = Get-Brush "#334155"
        $ResultIcon.Text = "⚖️"
        $ResultTitle.Text = "Aguardando arquivos para comparação"
        $ResultTitle.Foreground = Get-Brush "#E2E8F0"
        $ResultSubtitle.Text = "Arraste dois arquivos (individualmente ou os dois juntos de uma vez) para verificar se possuem o mesmo hash."
        $ResultSubtitle.Foreground = Get-Brush "#94A3B8"
        return
    }

    if ([string]::IsNullOrEmpty($script:State.File1) -or [string]::IsNullOrEmpty($script:State.File2)) {
        $ResultBanner.Background = Get-Brush "#1E293B"
        $ResultBanner.BorderBrush = Get-Brush "#3B82F6"
        $ResultIcon.Text = "⏳"
        $faltando = if ([string]::IsNullOrEmpty($script:State.File1)) { "1º arquivo" } else { "2º arquivo" }
        $ResultTitle.Text = "Aguardando o $faltando..."
        $ResultTitle.Foreground = Get-Brush "#93C5FD"
        $ResultSubtitle.Text = "Arraste o outro arquivo para a área ao lado para concluir a comparação."
        $ResultSubtitle.Foreground = Get-Brush "#94A3B8"
        return
    }

    if ($null -eq $script:State.Hash1 -or $null -eq $script:State.Hash2) {
        return
    }

    $samePath = ($script:State.File1 -ieq $script:State.File2)

    if ($script:State.Hash1 -eq $script:State.Hash2) {
        # ARQUIVOS IGUAIS
        $ResultBanner.Background = Get-Brush "#064E3B"
        $ResultBanner.BorderBrush = Get-Brush "#10B981"
        $ResultIcon.Text = "✅"
        $ResultTitle.Text = "OS ARQUIVOS SÃO IDÊNTICOS! (Hashes $algo iguais)"
        $ResultTitle.Foreground = Get-Brush "#6EE7B7"

        if ($samePath) {
            $ResultSubtitle.Text = "Nota: Ambos os lados apontam para exatamente o mesmo caminho de arquivo no disco."
        } else {
            $ResultSubtitle.Text = "O conteúdo binário dos dois arquivos é 100% igual ($($script:State.Hash1))."
        }
        $ResultSubtitle.Foreground = Get-Brush "#A7F3D0"

        $BorderZone1.BorderBrush = Get-Brush "#10B981"
        $BorderZone2.BorderBrush = Get-Brush "#10B981"
        $TxtHash1.Foreground = Get-Brush "#34D399"
        $TxtHash2.Foreground = Get-Brush "#34D399"
    }
    else {
        # ARQUIVOS DIFERENTES
        $ResultBanner.Background = Get-Brush "#450A0A"
        $ResultBanner.BorderBrush = Get-Brush "#EF4444"
        $ResultIcon.Text = "❌"
        $ResultTitle.Text = "OS ARQUIVOS SÃO DIFERENTES! (Hashes $algo distintos)"
        $ResultTitle.Foreground = Get-Brush "#FCA5A5"

        if ($script:State.Size1 -ne $script:State.Size2) {
            $diffBytes = [Math]::Abs($script:State.Size1 - $script:State.Size2)
            $ResultSubtitle.Text = "Os hashes não coincidem e os arquivos possuem tamanhos diferentes (diferença de $($diffBytes.ToString('N0')) bytes)."
        } else {
            $ResultSubtitle.Text = "Os arquivos têm o mesmo tamanho, mas seus conteúdos e hashes $algo são diferentes."
        }
        $ResultSubtitle.Foreground = Get-Brush "#FECACA"

        $BorderZone1.BorderBrush = Get-Brush "#EF4444"
        $BorderZone2.BorderBrush = Get-Brush "#EF4444"
        $TxtHash1.Foreground = Get-Brush "#F87171"
        $TxtHash2.Foreground = Get-Brush "#F87171"
    }
}

function Load-FileIntoSlot([int]$slot, [string]$filePath) {
    if ([string]::IsNullOrWhiteSpace($filePath)) { return }

    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        [System.Windows.MessageBox]::Show(
            "O item selecionado não é um arquivo válido (pastas não podem ser comparadas diretamente):`n`n$filePath",
            "Arquivo Inválido",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return
    }

    $fileInfo = Get-Item -LiteralPath $filePath
    $algo = Get-AlgorithmName

    if ($slot -eq 1) {
        $script:State.File1 = $fileInfo.FullName
        $script:State.Size1 = $fileInfo.Length
        $TxtFileName1.Text = $fileInfo.Name
        $TxtFilePath1.Text = $fileInfo.DirectoryName
        $TxtFilePath1.ToolTip = $fileInfo.FullName
        $TxtFileMeta1.Text = "Tamanho: $(Format-FileSize $fileInfo.Length)  •  Modificado: $($fileInfo.LastWriteTime.ToString('dd/MM/yyyy HH:mm'))"
        $BadgeInfo1.Visibility = [System.Windows.Visibility]::Visible
        $IconText1.Text = "📄"
        $DashRect1.Stroke = Get-Brush "#38BDF8"
        $BorderZone1.BorderBrush = Get-Brush "#334155"
        $TxtHash1.Text = "Calculando hash $algo..."
        $TxtHash1.Foreground = Get-Brush "#94A3B8"
    }
    else {
        $script:State.File2 = $fileInfo.FullName
        $script:State.Size2 = $fileInfo.Length
        $TxtFileName2.Text = $fileInfo.Name
        $TxtFilePath2.Text = $fileInfo.DirectoryName
        $TxtFilePath2.ToolTip = $fileInfo.FullName
        $TxtFileMeta2.Text = "Tamanho: $(Format-FileSize $fileInfo.Length)  •  Modificado: $($fileInfo.LastWriteTime.ToString('dd/MM/yyyy HH:mm'))"
        $BadgeInfo2.Visibility = [System.Windows.Visibility]::Visible
        $IconText2.Text = "📄"
        $DashRect2.Stroke = Get-Brush "#A78BFA"
        $BorderZone2.BorderBrush = Get-Brush "#334155"
        $TxtHash2.Text = "Calculando hash $algo..."
        $TxtHash2.Foreground = Get-Brush "#94A3B8"
    }

    # Forca atualizacao visual antes do calculo do hash
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

    try {
        $hash = Compute-FileHashString -filePath $fileInfo.FullName -algorithm $algo
        if ($slot -eq 1) {
            $script:State.Hash1 = $hash
            $TxtHash1.Text = $hash
            $TxtHash1.Foreground = Get-Brush "#E2E8F0"
            $BtnCopy1.IsEnabled = $true
        }
        else {
            $script:State.Hash2 = $hash
            $TxtHash2.Text = $hash
            $TxtHash2.Foreground = Get-Brush "#E2E8F0"
            $BtnCopy2.IsEnabled = $true
        }
    }
    catch {
        if ($slot -eq 1) {
            $script:State.Hash1 = $null
            $TxtHash1.Text = "Erro ao ler arquivo: $($_.Exception.Message)"
            $TxtHash1.Foreground = Get-Brush "#EF4444"
            $BtnCopy1.IsEnabled = $false
        }
        else {
            $script:State.Hash2 = $null
            $TxtHash2.Text = "Erro ao ler arquivo: $($_.Exception.Message)"
            $TxtHash2.Foreground = Get-Brush "#EF4444"
            $BtnCopy2.IsEnabled = $false
        }
    }

    Update-ComparisonBanner
}

function Clear-AllSlots {
    $script:State.File1 = $null
    $script:State.File2 = $null
    $script:State.Hash1 = $null
    $script:State.Hash2 = $null
    $script:State.Size1 = 0L
    $script:State.Size2 = 0L

    $TxtFileName1.Text = "Arraste o 1º arquivo aqui"
    $TxtFilePath1.Text = "ou clique para selecionar no computador"
    $TxtFilePath1.ToolTip = $null
    $BadgeInfo1.Visibility = [System.Windows.Visibility]::Collapsed
    $IconText1.Text = "📥"
    $DashRect1.Stroke = Get-Brush "#475569"
    $BorderZone1.BorderBrush = Get-Brush "#334155"
    $TxtHash1.Text = "Nenhum arquivo selecionado"
    $TxtHash1.Foreground = Get-Brush "#64748B"
    $BtnCopy1.IsEnabled = $false

    $TxtFileName2.Text = "Arraste o 2º arquivo aqui"
    $TxtFilePath2.Text = "ou clique para selecionar no computador"
    $TxtFilePath2.ToolTip = $null
    $BadgeInfo2.Visibility = [System.Windows.Visibility]::Collapsed
    $IconText2.Text = "📥"
    $DashRect2.Stroke = Get-Brush "#475569"
    $BorderZone2.BorderBrush = Get-Brush "#334155"
    $TxtHash2.Text = "Nenhum arquivo selecionado"
    $TxtHash2.Foreground = Get-Brush "#64748B"
    $BtnCopy2.IsEnabled = $false

    Update-ComparisonBanner
}

function Recalculate-All {
    if (-not [string]::IsNullOrEmpty($script:State.File1)) {
        Load-FileIntoSlot -slot 1 -filePath $script:State.File1
    }
    if (-not [string]::IsNullOrEmpty($script:State.File2)) {
        Load-FileIntoSlot -slot 2 -filePath $script:State.File2
    }
}

function Open-FilePicker([int]$slot) {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Selecione o Arquivo $slot para comparar"
    $dialog.Filter = "Todos os arquivos (*.*)|*.*"
    $dialog.Multiselect = $true
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $files = $dialog.FileNames
        if ($files.Count -ge 2) {
            Load-FileIntoSlot -slot 1 -filePath $files[0]
            Load-FileIntoSlot -slot 2 -filePath $files[1]
        }
        elseif ($files.Count -eq 1) {
            Load-FileIntoSlot -slot $slot -filePath $files[0]
        }
    }
}

# Eventos Drag & Drop - Zona 1
$DropZone1.Add_DragEnter({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
        $BorderZone1.Background = Get-Brush "#1E3A5F"
        $DashRect1.Stroke = Get-Brush "#38BDF8"
    } else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
})

$DropZone1.Add_DragOver({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    } else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
})

$DropZone1.Add_DragLeave({
    param($sender, $e)
    $BorderZone1.Background = Get-Brush "#1E293B"
    if ([string]::IsNullOrEmpty($script:State.File1)) {
        $DashRect1.Stroke = Get-Brush "#475569"
    } else {
        $DashRect1.Stroke = Get-Brush "#38BDF8"
    }
})

$DropZone1.Add_Drop({
    param($sender, $e)
    $BorderZone1.Background = Get-Brush "#1E293B"
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = [string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        if ($files.Count -ge 2) {
            Load-FileIntoSlot -slot 1 -filePath $files[0]
            Load-FileIntoSlot -slot 2 -filePath $files[1]
        }
        elseif ($files.Count -eq 1) {
            Load-FileIntoSlot -slot 1 -filePath $files[0]
        }
    }
    $e.Handled = $true
})

# Eventos Drag & Drop - Zona 2
$DropZone2.Add_DragEnter({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
        $BorderZone2.Background = Get-Brush "#2E1065"
        $DashRect2.Stroke = Get-Brush "#A78BFA"
    } else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
})

$DropZone2.Add_DragOver({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    } else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
})

$DropZone2.Add_DragLeave({
    param($sender, $e)
    $BorderZone2.Background = Get-Brush "#1E293B"
    if ([string]::IsNullOrEmpty($script:State.File2)) {
        $DashRect2.Stroke = Get-Brush "#475569"
    } else {
        $DashRect2.Stroke = Get-Brush "#A78BFA"
    }
})

$DropZone2.Add_Drop({
    param($sender, $e)
    $BorderZone2.Background = Get-Brush "#1E293B"
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = [string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        if ($files.Count -ge 2) {
            Load-FileIntoSlot -slot 1 -filePath $files[0]
            Load-FileIntoSlot -slot 2 -filePath $files[1]
        }
        elseif ($files.Count -eq 1) {
            Load-FileIntoSlot -slot 2 -filePath $files[0]
        }
    }
    $e.Handled = $true
})

# Cliques nos botoes e cards
$BtnSelect1.Add_Click({ Open-FilePicker -slot 1 })
$BtnSelect2.Add_Click({ Open-FilePicker -slot 2 })

$DropZone1.Add_MouseLeftButtonUp({
    param($sender, $e)
    if ($e.OriginalSource -isnot [System.Windows.Controls.Primitives.TextBoxBase] -and
        $e.OriginalSource.TemplatedParent -isnot [System.Windows.Controls.Button]) {
        Open-FilePicker -slot 1
    }
})

$DropZone2.Add_MouseLeftButtonUp({
    param($sender, $e)
    if ($e.OriginalSource -isnot [System.Windows.Controls.Primitives.TextBoxBase] -and
        $e.OriginalSource.TemplatedParent -isnot [System.Windows.Controls.Button]) {
        Open-FilePicker -slot 2
    }
})

$BtnCopy1.Add_Click({
    if (-not [string]::IsNullOrEmpty($script:State.Hash1)) {
        [System.Windows.Clipboard]::SetText($script:State.Hash1)
        $BtnCopy1.Content = "Copiado!"
    }
})

$BtnCopy2.Add_Click({
    if (-not [string]::IsNullOrEmpty($script:State.Hash2)) {
        [System.Windows.Clipboard]::SetText($script:State.Hash2)
        $BtnCopy2.Content = "Copiado!"
    }
})

$CmbAlgorithm.Add_SelectionChanged({
    if ($window.IsLoaded) {
        $BtnCopy1.Content = "Copiar Hash"
        $BtnCopy2.Content = "Copiar Hash"
        Recalculate-All
    }
})

$BtnClear.Add_Click({
    $BtnCopy1.Content = "Copiar Hash"
    $BtnCopy2.Content = "Copiar Hash"
    Clear-AllSlots
})

$BtnRecalculate.Add_Click({
    $BtnCopy1.Content = "Copiar Hash"
    $BtnCopy2.Content = "Copiar Hash"
    Recalculate-All
})

# Exibe a janela
$window.ShowDialog() | Out-Null
